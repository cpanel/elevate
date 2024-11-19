#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032 qw<nostrict>;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

use Elevate::Usage;

require $FindBin::Bin . '/../elevate-cpanel';

my @skip = qw{ ALL ALWAYS AUTOLOAD BEGIN DESTROY DEBUG ERROR FATAL INFO INIT LOGCARP LOGCLUCK LOGCONFESS LOGCROAK LOGDIE LOGEXIT LOGWARN OFF OS TRACE WARN SUPPORTED_DISTROS get_logger _set_cache clear_cache factory instance supported_methods };

my @stash = sort keys %{Elevate::OS::};

foreach my $os (qw{ CentOS7 CloudLinux7 Ubuntu20 }) {
    note "Test $os";
    set_os_to($os);

    foreach my $sub (@stash) {
        next if $sub =~ m{::};
        next if grep { $_ eq $sub } @skip;

        my $pkg = "Elevate::OS::$os";
        ok( $pkg->can($sub), "Elevate::OS::${os}::$sub" );
    }
}

done_testing();
exit;
