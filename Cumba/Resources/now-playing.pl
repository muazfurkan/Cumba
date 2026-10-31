# Runs Cumba's Now Playing helper (Contents/Frameworks/libCumbaNowPlaying.dylib) inside the
# system perl, which macOS still lets read the system's Now Playing. Cumba starts it with an
# empty environment, so no PERL5OPT or PERL5LIB from outside can change what runs.
use strict;
use warnings;
use DynaLoader;

my ($library) = @ARGV;
my $handle = DynaLoader::dl_load_file($library, 0) or die DynaLoader::dl_error();
my $entry = DynaLoader::dl_find_symbol($handle, 'cumba_now_playing_run')
  or die DynaLoader::dl_error();
DynaLoader::dl_install_xsub('Cumba::run', $entry)->();
