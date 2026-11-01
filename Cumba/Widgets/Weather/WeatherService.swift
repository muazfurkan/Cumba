import Foundation

/// Open-Meteo forecast and geocoding (free, no key). Requests go out only for the place the
/// user picked, without cookies or cache; they are listed in the README privacy section.
struct WeatherService: Sendable {
  struct Place: Codable, Equatable, Identifiable, Sendable {
    var name: String
    var region: String?
    var country: String?
    var latitude: Double
    var longitude: Double

    var id: String { "\(latitude),\(longitude)" }
    var label: String { [name, region, country].compactMap { $0 }.joined(separator: ", ") }
  }

  struct Forecast: Equatable, Sendable {
    var temperature: Double
    var high: Double?
    var low: Double?
    var code: Int
    var isDay: Bool
    var unit: String
    /// Every hour from the current one to the end of the last day.
    var hours: [Hour] = []
    /// Today and the next days.
    var days: [Day] = []
  }

  struct Hour: Equatable, Sendable, Identifiable {
    var time: Date
    var temperature: Double
    var code: Int
    var isDay: Bool
    var id: Date { time }
  }

  struct Day: Equatable, Sendable, Identifiable {
    var date: Date
    var high: Double?
    var low: Double?
    var code: Int
    var id: Date { date }
  }

  enum Failure: Error, Equatable {
    case badResponse
  }

  private let session: URLSession

  init() {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 10
    configuration.httpCookieStorage = nil
    configuration.urlCache = nil
    session = URLSession(configuration: configuration)
  }

  func forecast(for place: Place, fahrenheit: Bool) async throws -> Forecast {
    let (data, response) = try await session.data(
      from: Self.forecastURL(for: place, fahrenheit: fahrenheit))
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.badResponse }
    return try Self.parseForecast(data)
  }

  func search(_ query: String) async throws -> [Place] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return [] }
    let (data, response) = try await session.data(from: Self.searchURL(for: trimmed))
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.badResponse }
    return try Self.parsePlaces(data)
  }

  // MARK: - Pure helpers

  static func forecastURL(for place: Place, fahrenheit: Bool) -> URL {
    var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
    components?.queryItems = [
      URLQueryItem(name: "latitude", value: String(format: "%.4f", place.latitude)),
      URLQueryItem(name: "longitude", value: String(format: "%.4f", place.longitude)),
      URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
      URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,is_day"),
      URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code"),
      URLQueryItem(name: "forecast_days", value: "6"),
      URLQueryItem(name: "timezone", value: "auto"),
      URLQueryItem(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius"),
    ]
    return components?.url ?? URL(filePath: "/")
  }

  static func searchURL(for query: String) -> URL {
    var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
    components?.queryItems = [
      URLQueryItem(name: "name", value: query),
      URLQueryItem(name: "count", value: "5"),
      URLQueryItem(
        name: "language", value: Locale.current.language.languageCode?.identifier ?? "en"),
      URLQueryItem(name: "format", value: "json"),
    ]
    return components?.url ?? URL(filePath: "/")
  }

  static func parseForecast(_ data: Data) throws -> Forecast {
    struct Response: Decodable {
      struct Current: Decodable {
        let time: String?
        let temperature: Double
        let weatherCode: Int
        let isDay: Int?

        enum CodingKeys: String, CodingKey {
          case time
          case temperature = "temperature_2m"
          case weatherCode = "weather_code"
          case isDay = "is_day"
        }
      }
      struct Hourly: Decodable {
        let time: [String]
        let temperature: [Double?]
        let code: [Int?]
        let isDay: [Int?]?

        enum CodingKeys: String, CodingKey {
          case time
          case temperature = "temperature_2m"
          case code = "weather_code"
          case isDay = "is_day"
        }
      }
      struct Units: Decodable {
        let temperature: String?

        enum CodingKeys: String, CodingKey {
          case temperature = "temperature_2m"
        }
      }
      struct Daily: Decodable {
        let time: [String]?
        let high: [Double?]?
        let low: [Double?]?
        let code: [Int?]?

        enum CodingKeys: String, CodingKey {
          case time
          case high = "temperature_2m_max"
          case low = "temperature_2m_min"
          case code = "weather_code"
        }
      }
      let current: Current
      let units: Units?
      let hourly: Hourly?
      let daily: Daily?
      let offset: Int?

      enum CodingKeys: String, CodingKey {
        case current
        case units = "current_units"
        case hourly
        case daily
        case offset = "utc_offset_seconds"
      }
    }
    let response = try JSONDecoder().decode(Response.self, from: data)
    // Times come in the place's local time without an offset.
    let zone = TimeZone(secondsFromGMT: response.offset ?? 0) ?? .current
    let hourFormat = Date.ISO8601FormatStyle(timeZone: zone)
      .year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: false)
      .timeSeparator(.colon)
    func hourDate(_ text: String) -> Date? { try? hourFormat.parse(text + ":00") }
    let dayFormat = Date.ISO8601FormatStyle(timeZone: zone).year().month().day()
      .dateSeparator(.dash)

    let now = response.current.time.flatMap(hourDate) ?? .distantPast
    let currentHour = now.addingTimeInterval(-3599)
    var hours: [Hour] = []
    if let hourly = response.hourly {
      for index in hourly.time.indices {
        guard let time = hourDate(hourly.time[index]), time > currentHour,
          let temperature = hourly.temperature[safe: index] ?? nil,
          let code = hourly.code[safe: index] ?? nil
        else { continue }
        let isDay = (hourly.isDay?[safe: index] ?? nil).map { $0 != 0 } ?? true
        hours.append(Hour(time: time, temperature: temperature, code: code, isDay: isDay))
      }
    }
    var days: [Day] = []
    if let daily = response.daily, let times = daily.time {
      for index in times.indices {
        guard let date = try? dayFormat.parse(times[index]) else { continue }
        days.append(
          Day(
            date: date, high: daily.high?[safe: index] ?? nil, low: daily.low?[safe: index] ?? nil,
            code: (daily.code?[safe: index] ?? nil) ?? response.current.weatherCode))
      }
    }
    return Forecast(
      temperature: response.current.temperature,
      high: response.daily?.high?.first ?? nil,
      low: response.daily?.low?.first ?? nil,
      code: response.current.weatherCode,
      isDay: response.current.isDay != 0,
      unit: response.units?.temperature ?? "°",
      hours: hours, days: days)
  }

  static func parsePlaces(_ data: Data) throws -> [Place] {
    struct Response: Decodable {
      struct Result: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let admin1: String?
      }
      let results: [Result]?
    }
    return try JSONDecoder().decode(Response.self, from: data).results?.map {
      Place(
        name: $0.name, region: $0.admin1 == $0.name ? nil : $0.admin1, country: $0.country,
        latitude: $0.latitude, longitude: $0.longitude)
    } ?? []
  }

  /// SF Symbol and description for a WMO weather code.
  static func condition(for code: Int, isDay: Bool) -> (symbol: String, text: String) {
    switch code {
    case 0:
      (isDay ? "sun.max.fill" : "moon.stars.fill", String(localized: "Clear", comment: "Weather"))
    case 1, 2:
      (
        isDay ? "cloud.sun.fill" : "cloud.moon.fill",
        String(localized: "Partly cloudy", comment: "Weather")
      )
    case 3: ("cloud.fill", String(localized: "Cloudy", comment: "Weather"))
    case 45, 48: ("cloud.fog.fill", String(localized: "Fog", comment: "Weather"))
    case 51, 53, 55, 56, 57:
      ("cloud.drizzle.fill", String(localized: "Drizzle", comment: "Weather"))
    case 61, 63, 66: ("cloud.rain.fill", String(localized: "Rain", comment: "Weather"))
    case 65, 67: ("cloud.heavyrain.fill", String(localized: "Heavy rain", comment: "Weather"))
    case 71, 73, 75, 77, 85, 86: ("cloud.snow.fill", String(localized: "Snow", comment: "Weather"))
    case 80, 81, 82: ("cloud.sun.rain.fill", String(localized: "Showers", comment: "Weather"))
    case 95, 96, 99: ("cloud.bolt.rain.fill", String(localized: "Thunderstorm", comment: "Weather"))
    default: ("thermometer.medium", String(localized: "Unknown", comment: "Weather"))
    }
  }
}

extension Array {
  subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
