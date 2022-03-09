#!/usr/local/cpanel/3rdparty/bin/perl

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Test::MockModule qw/strict/;

use cPstrict;
require $FindBin::Bin . '/../elevate-cpanel';

#my $cpev_mock = Test::MockModule->new('cpev');

my $sr_mock     = Test::MockModule->new('Cpanel::SafeRun::Errors');
my $mock_output = do { local $/; <DATA> };
$sr_mock->redefine( 'saferunnoerror' => sub { return $mock_output } );

my $installed = cpev::yum_list();
is(
    [ sort keys %$installed ],
    [
        qw/EA4 EA4-developer-feed Mysql57-community
          base cp-dev-tools cpanel-plugins epel extras
          google-chrome updates wp-toolkit-cpanel
          wp-toolkit-thirdparties/
    ],
    "repos are what we'd expect."
);
is(
    $installed->{'cpanel-plugins'},
    [
        {
            'arch'    => 'noarch',
            'package' => 'cpanel-analytics',
            'version' => '1.4.9-1.2.1.cpanel'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'cpanel-ccs-calendarserver',
            'version' => '9.2.a-83.86.1.cpanel'
        },
        {
            'arch'    => 'noarch',
            'package' => 'cpanel-monitoring-agent',
            'version' => '1.0.0-33.1'
        }
    ],
    "cpanel-plugins looks like we'd expect."
);

is(
    $installed->{'wp-toolkit-thirdparties'},
    [
        {
            'arch'    => 'x86_64',
            'package' => 'libaps',
            'version' => '1.0.10-1centos.7.191108.1550'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'log4cplus',
            'version' => '1.2.0.1-1centos.7.191108.1550'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-libboost-1.65',
            'version' => '1.65.1-1centos.7.190116.1809'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-libboost-date-time1.65',
            'version' => '1.65.1-1centos.7.190116.1809'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-libboost-filesystem1.65',
            'version' => '1.65.1-1centos.7.190116.1809'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-libboost-program-options1.65',
            'version' => '1.65.1-1centos.7.190116.1809'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-libboost-regex1.65',
            'version' => '1.65.1-1centos.7.190116.1809'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-libboost-serialization1.65',
            'version' => '1.65.1-1centos.7.190116.1809'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-libboost-system1.65',
            'version' => '1.65.1-1centos.7.190116.1809'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-libboost-thread1.65',
            'version' => '1.65.1-1centos.7.190116.1809'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-libpoco-1.9.0',
            'version' => '1.9.0-1centos.7.191202.1336'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-libstdc++6.3.0',
            'version' => '6.3.0-1centos.7.190110.1553'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-lmlib',
            'version' => '0.2.4-1centos.7.191108.1550'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-platform-runtime',
            'version' => '1.0.2-1centos.7.191108.1550'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'plesk-rdbmspp',
            'version' => '2.0.2-1centos.7.191108.1550'
        },
        {
            'arch'    => 'x86_64',
            'package' => 'sw-engine',
            'version' => '2.27.2-1centos.7.191108.1550'
        }
    ],
    "Parsing of long lines in wp-toolkit-thirdparties where yum wraps still produces expected columns"
);

done_testing();
exit;

# __DATA__ is yum list installed|cat
__DATA__
Loaded plugins: fastestmirror, universal-hooks
Installed Packages
GConf2.x86_64                                  3.2.6-8.el7             @base    
GeoIP.x86_64                                   1.5.0-14.el7            @base    
ImageMagick.x86_64                             6.9.10.68-6.el7_9       @updates 
ImageMagick-devel.x86_64                       6.9.10.68-6.el7_9       @updates 
ImageMagick-perl.x86_64                        6.9.10.68-6.el7_9       @updates 
NetworkManager.x86_64                          1:1.18.8-2.el7_9        @updates 
NetworkManager-libnm.x86_64                    1:1.18.8-2.el7_9        @updates 
NetworkManager-team.x86_64                     1:1.18.8-2.el7_9        @updates 
NetworkManager-tui.x86_64                      1:1.18.8-2.el7_9        @updates 
ORBit2.x86_64                                  2.14.19-13.el7          @base    
OpenEXR-libs.x86_64                            1.7.1-8.el7             @base    
PyYAML.x86_64                                  3.10-11.el7             installed
SDL.x86_64                                     1.2.15-17.el7           @base    
ack.noarch                                     2.26-1.el7              @epel    
acl.x86_64                                     2.2.51-15.el7           installed
acpid.x86_64                                   2.0.19-9.el7            @base    
adobe-mappings-cmap.noarch                     20171205-3.el7          @base    
adobe-mappings-cmap-deprecated.noarch          20171205-3.el7          @base    
adobe-mappings-pdf.noarch                      20180407-1.el7          @base    
adwaita-cursor-theme.noarch                    3.28.0-1.el7            @base    
adwaita-icon-theme.noarch                      3.28.0-1.el7            @base    
agg.x86_64                                     2.5-18.el7              @base    
aic94xx-firmware.noarch                        30-6.el7                @base    
alsa-firmware.noarch                           1.0.28-2.el7            @base    
alsa-lib.x86_64                                1.1.8-1.el7             @base    
alsa-tools-firmware.x86_64                     1.1.0-1.el7             @base    
asciidoc.noarch                                8.6.8-5.el7             @base    
aspell.x86_64                                  12:0.60.6.1-9.el7       @base    
at.x86_64                                      3.1.13-24.el7           @base    
at-spi2-atk.x86_64                             2.26.2-1.el7            @base    
at-spi2-core.x86_64                            2.28.0-1.el7            @base    
atk.x86_64                                     2.28.1-2.el7            @base    
atlas.x86_64                                   3.10.1-12.el7           @base    
audit.x86_64                                   2.8.5-4.el7             installed
audit-libs.x86_64                              2.8.5-4.el7             installed
audit-libs-python.x86_64                       2.8.5-4.el7             installed
authconfig.x86_64                              6.2.8-30.el7            installed
autoconf.noarch                                2.69-11.el7             @base    
autogen-libopts.x86_64                         5.18-5.el7              @base    
automake.noarch                                1.13.4-3.el7            @base    
avahi-libs.x86_64                              0.6.31-20.el7           @base    
basesystem.noarch                              10.0-7.el7.centos       installed
bash.x86_64                                    4.2.46-35.el7_9         @updates 
bc.x86_64                                      1.06.95-13.el7          @base    
bind.x86_64                                    32:9.11.4-26.P2.el7_9.8 @updates 
bind-devel.x86_64                              32:9.11.4-26.P2.el7_9.8 @updates 
bind-export-libs.x86_64                        32:9.11.4-26.P2.el7_9.8 @updates 
bind-libs.x86_64                               32:9.11.4-26.P2.el7_9.8 @updates 
bind-libs-lite.x86_64                          32:9.11.4-26.P2.el7_9.8 @updates 
bind-license.noarch                            32:9.11.4-26.P2.el7_9.8 @updates 
bind-lite-devel.x86_64                         32:9.11.4-26.P2.el7_9.8 @updates 
bind-utils.x86_64                              32:9.11.4-26.P2.el7_9.8 @updates 
binutils.x86_64                                2.27-44.base.el7_9.1    @updates 
biosdevname.x86_64                             0.7.3-2.el7             @base    
bison.x86_64                                   3.0.4-2.el7             @base    
blas.x86_64                                    3.4.2-8.el7             @base    
boost.x86_64                                   1.53.0-28.el7           @base    
boost-atomic.x86_64                            1.53.0-28.el7           @base    
boost-chrono.x86_64                            1.53.0-28.el7           @base    
boost-context.x86_64                           1.53.0-28.el7           @base    
boost-date-time.x86_64                         1.53.0-28.el7           @base    
boost-devel.x86_64                             1.53.0-28.el7           @base    
boost-filesystem.x86_64                        1.53.0-28.el7           @base    
boost-graph.x86_64                             1.53.0-28.el7           @base    
boost-iostreams.x86_64                         1.53.0-28.el7           @base    
boost-locale.x86_64                            1.53.0-28.el7           @base    
boost-math.x86_64                              1.53.0-28.el7           @base    
boost-program-options.x86_64                   1.53.0-28.el7           @base    
boost-python.x86_64                            1.53.0-28.el7           @base    
boost-random.x86_64                            1.53.0-28.el7           @base    
boost-regex.x86_64                             1.53.0-28.el7           @base    
boost-serialization.x86_64                     1.53.0-28.el7           @base    
boost-signals.x86_64                           1.53.0-28.el7           @base    
boost-system.x86_64                            1.53.0-28.el7           @base    
boost-test.x86_64                              1.53.0-28.el7           @base    
boost-thread.x86_64                            1.53.0-28.el7           @base    
boost-timer.x86_64                             1.53.0-28.el7           @base    
boost-wave.x86_64                              1.53.0-28.el7           @base    
btrfs-progs.x86_64                             4.9.1-1.el7             @base    
bzip2.x86_64                                   1.0.6-13.el7            @base    
bzip2-devel.x86_64                             1.0.6-13.el7            @base    
bzip2-libs.x86_64                              1.0.6-13.el7            installed
ca-certificates.noarch                         2021.2.50-72.el7_9      @updates 
cairo.x86_64                                   1.15.12-4.el7           @base    
cairo-gobject.x86_64                           1.15.12-4.el7           @base    
ccache.x86_64                                  3.7.7-1.el7             @epel    
centos-indexhtml.noarch                        7-9.el7.centos          @base    
centos-logos.noarch                            70.0.6-3.el7.centos     @base    
centos-release.x86_64                          7-9.2009.1.el7.centos   @updates 
checkpolicy.x86_64                             2.5-8.el7               installed
chkconfig.x86_64                               1.7.6-1.el7             @base    
chrony.x86_64                                  3.4-1.el7               installed
cloud-init.x86_64                              19.4-7.el7.centos.5     @updates 
cloud-utils-growpart.noarch                    0.29-5.el7              installed
clucene-core.x86_64                            2.3.3.4-11.el7          @base    
clufter-bin.x86_64                             0.77.1-1.el7            @base    
clufter-common.noarch                          0.77.1-1.el7            @base    
clufter-lib-ccs.noarch                         0.77.1-1.el7            @base    
clufter-lib-general.noarch                     0.77.1-1.el7            @base    
cmake.x86_64                                   2.8.12.2-2.el7          @base    
cmake3.x86_64                                  3.17.5-1.el7            @epel    
cmake3-data.noarch                             3.17.5-1.el7            @epel    
colord-libs.x86_64                             1.3.4-2.el7             @base    
colordiff.noarch                               1.0.19-1.el7            @epel    
compat-db.x86_64                               4.7.25-28.el7           @base    
compat-db-headers.noarch                       4.7.25-28.el7           @base    
compat-db47.x86_64                             4.7.25-28.el7           @base    
copy-jdk-configs.noarch                        3.3-10.el7_5            @base    
coreutils.x86_64                               8.22-24.el7_9.2         @updates 
cp-dev-tools-release.noarch                    1-3.3.cpanel            installed
cpanel-ace-editor.noarch                       1.3.1-1.cp1198          installed
cpanel-analog.x86_64                           6.0-1.cp1198            installed
cpanel-analytics.noarch                        1.4.9-1.2.1.cpanel      @cpanel-plugins
cpanel-analytics.noarch                        1.4.10-1.4.1.cpanel     installed
cpanel-angular-chosen.noarch                   1.4.0-1.cp1198          installed
cpanel-angular-growl-2.noarch                  0.7.3-1.cp1198          installed
cpanel-angular-ui-bootstrap.noarch             1.2.5-1.cp1198          installed
cpanel-angular-ui-bootstrap-devel.noarch       1.2.5-1.cp1198          installed
cpanel-angular-ui-scroll.noarch                1.6.1-1.cp1198          installed
cpanel-angularjs.noarch                        1.4.4-1.cp1198          installed
cpanel-awstats.noarch                          7.8-1.cp1198            installed
cpanel-bindp.x86_64                            1.0.0-1.cp1198          installed
cpanel-bootstrap.noarch                        3.1.1-1.cp1198          installed
cpanel-bootstrap-devel.noarch                  3.1.1-1.cp1198          installed
cpanel-bootstrap-rtl.noarch                    0.9.16-1.cp1198         installed
cpanel-bootstrap-rtl-devel.noarch              0.9.16-1.cp1198         installed
cpanel-bootstrap5.noarch                       5.0.1-3.cp1198          installed
cpanel-ccs-calendarserver.x86_64               9.2.a-83.86.1.cpanel    @cpanel-plugins
cpanel-chosen.noarch                           1.5.1-1.cp1198          installed
cpanel-chosen-1.1.0.noarch                     1.1.0-1.cp1186          installed
cpanel-ckeditor.noarch                         4.17.1-1.cp1198         installed
cpanel-ckeditor-devel.noarch                   4.17.1-1.cp1198         installed
cpanel-clamav.x86_64                           0.104.0-1.cp11100       installed
cpanel-common-licenses.noarch                  1.0.0-1.cp1198          installed
cpanel-cplint.x86_64                           1.2.0-4.cp1198          installed
cpanel-d3-js.noarch                            3.5.6-1.cp1198          installed
cpanel-dnspython.x86_64                        1.12.0-1.cp1198         installed
cpanel-dovecot.x86_64                          2.3.15-3.cp11100        installed
cpanel-dovecot-xaps.x86_64                     2.3.15-3.cp11100        installed
cpanel-dpkg.noarch                             11.98-1.cp1198          installed
cpanel-editarea.noarch                         0.8.2-1.cp1198          installed
cpanel-elfinder.noarch                         2.1.11-1.cp1198         installed
cpanel-elfinder-devel.noarch                   2.1.11-1.cp1198         installed
cpanel-eventsource-polyfill-js.noarch          1.0.0-1.cp1198          installed
cpanel-exim.x86_64                             4.95-1.cp11104          installed
cpanel-fetch-polyfill-js-v3.0.noarch           3.0.0-1.cp1198          installed
cpanel-flot.noarch                             0.7-1.cp1198            installed
cpanel-fontawesome.noarch                      5.11.2-1.cp1198         installed
cpanel-geoipfree-data.noarch                   104.0-1.cp11104         installed
cpanel-git.x86_64                              2.34.1-1.cp1198         installed
cpanel-git-gitweb.x86_64                       2.34.1-1.cp1198         installed
cpanel-git-templates.x86_64                    2.34.1-1.cp1198         installed
cpanel-grunt-cpanel-optimizer.noarch           1.1.0-4.cp1198          installed
cpanel-handlebarsjs.noarch                     1.0.0-1.cp1198          installed
cpanel-imap-php-devel.x86_64                   2007f-1.cp1198          installed
cpanel-jquery.noarch                           3.6.0-1.cp1198          installed
cpanel-jsforge.noarch                          0.7.0-1.cp1198          installed
cpanel-jstz.noarch                             1.0.4-1.cp1198          installed
cpanel-knownproxies-data.noarch                104.0-1.cp11104         installed
cpanel-ldns.x86_64                             1.8.1-2.cp1198          installed
cpanel-libmcrypt.x86_64                        2.5.8-1.cp1198          installed
cpanel-libmcrypt-devel.x86_64                  2.5.8-1.cp1198          installed
cpanel-libspf2.x86_64                          1.2.10-2.cp1198         installed
cpanel-libspf2-devel.x86_64                    1.2.10-2.cp1198         installed
cpanel-libsrs-alt.x86_64                       1.0-1.cp1198            installed
cpanel-libsrs-alt-devel.x86_64                 1.0-1.cp1198            installed
cpanel-libtap.x86_64                           0.1.0a-1.cp1198         installed
cpanel-libtidy.x86_64                          1.1-1.cp1198            installed
cpanel-libtidy-devel.x86_64                    1.1-1.cp1198            installed
cpanel-lodash.noarch                           4.8.2-1.cp1198          installed
cpanel-lodash-devel.noarch                     4.8.2-1.cp1198          installed
cpanel-mailman.x86_64                          2.1.38-1.cp1198         installed
cpanel-mariadb-connector.x86_64                3.1.8-1.cp1198          installed
cpanel-moment.noarch                           2.9.0-1.cp1198          installed
cpanel-moment-devel.noarch                     2.9.0-1.cp1198          installed
cpanel-monitoring-agent.noarch                 1.0.0-33.1              @cpanel-plugins
cpanel-mysql.x86_64                            5.6.43-1.cp1198         installed
cpanel-mysql-devel.x86_64                      5.6.43-1.cp1198         installed
cpanel-mysql-libs.x86_64                       5.6.43-1.cp1198         installed
cpanel-ng-cpanel-jupiter-clam-av.noarch        5-1.cp1198              installed
cpanel-ng-cpanel-jupiter-dynamic-dns.noarch    8-1.cp11100             installed
cpanel-ng-cpanel-jupiter-manage-calendar-access.noarch
                                               4-1.cp1198              installed
cpanel-ng-cpanel-jupiter-mysql-manager.noarch  5-1.cp11102             installed
cpanel-ng-cpanel-paper.lantern-clam-av.noarch  9-1.cp1198              installed
cpanel-ng-cpanel-paper.lantern-dynamic-dns.noarch
                                               14-1.cp11100            installed
cpanel-ng-cpanel-paper.lantern-manage-calendar-access.noarch
                                               15-1.cp1198             installed
cpanel-ng-cpanel-paper.lantern-mysql-manager.noarch
                                               5-1.cp1198              installed
cpanel-ng-whm-account-enhancements.noarch      4-1.cp1198              installed
cpanel-ng-whm-accounts-manager.noarch          2-1.cp11100             installed
cpanel-ng-whm-connected-applications.noarch    6-1.cp1198              installed
cpanel-ng-whm-link-server-nodes.noarch         31-1.cp11104            installed
cpanel-ng-whm-multiphp-manager-ng7.noarch      26-1.cp1198             installed
cpanel-ng-whm-nginx-manager.noarch             13-1.cp11102            installed
cpanel-ng-whm-ssl-tls-configuration.noarch     10-1.cp1198             installed
cpanel-ng-whm-transfer-cpanel-account.noarch   33-1.cp1198             installed
cpanel-ng-whm-wh-sql-config.noarch             6-1.cp11104             installed
cpanel-ng-whm-whm-marketplace.noarch           29-1.cp11100            installed
cpanel-node.x86_64                             14.17.0-1.cp1198        installed
cpanel-node-packages.x86_64                    5.0-3.cp1198            installed
cpanel-oniguruma.x86_64                        6.9.7.1-5.cp11102       installed
cpanel-oniguruma-devel.x86_64                  6.9.7.1-5.cp11102       installed
cpanel-open-sans.noarch                        1.0-1.cp1198            installed
cpanel-open-sans-devel.noarch                  1.0-1.cp1198            installed
cpanel-p0f.x86_64                              3.09b-1.cp1198          installed
cpanel-pam-cpses.x86_64                        72.1-3.cp1198           installed
cpanel-pam-hulk.x86_64                         98.1-1.cp1198           installed
cpanel-pdns.x86_64                             4.4.1-3.cp11100         installed
cpanel-perl-532.x86_64                         5.32.0-2.cp1198         installed
cpanel-perl-532-ack.x86_64                     3.4.0-1.cp1198          installed
cpanel-perl-532-acme-bleach.noarch             1.150-1.cp1198          installed
cpanel-perl-532-acme-damn.x86_64               0.08-1.cp1198           installed
cpanel-perl-532-acme-spork.noarch              0.0.8-1.cp1198          installed
cpanel-perl-532-algorithm-c3.noarch            0.10-1.cp1198           installed
cpanel-perl-532-algorithm-combinatorics.x86_64 0.27-1.cp1198           installed
cpanel-perl-532-algorithm-dependency.noarch    1.112-1.cp1198          installed
cpanel-perl-532-algorithm-diff.noarch          1.200-1.cp1198          installed
cpanel-perl-532-aliased.noarch                 0.34-1.cp1198           installed
cpanel-perl-532-amazon-s3.noarch               0.45-2.cp1198           installed
cpanel-perl-532-any-uri-escape.noarch          0.01-1.cp1198           installed
cpanel-perl-532-anyevent.noarch                7.17-2.cp1198           installed
cpanel-perl-532-anyevent-aio.noarch            1.1-1.cp1198            installed
cpanel-perl-532-anyevent-rabbitmq.noarch       1.22-1.cp1198           installed
cpanel-perl-532-anyevent-xmpp.noarch           0.55-1.cp1198           installed
cpanel-perl-532-apache-logformat-compiler.noarch
                                               0.36-1.cp1198           installed
cpanel-perl-532-apache-session.noarch          1.94-1.cp1198           installed
cpanel-perl-532-apache-session-browseable.noarch
                                               1.3.8-1.cp1198          installed
cpanel-perl-532-app-cmd.noarch                 0.331-1.cp1198          installed
cpanel-perl-532-app-cmddispatch.noarch         0.44-1.cp1198           installed
cpanel-perl-532-app-cpanminus.noarch           1.7044-1.cp1198         installed
cpanel-perl-532-app-nopaste.noarch             1.013-1.cp1198          installed
cpanel-perl-532-app-perlbrew.noarch            0.89-1.cp1198           installed
cpanel-perl-532-app-prove-plugin-elasticsearch.noarch
                                               0.001-1.cp1198          installed
cpanel-perl-532-appconfig.noarch               1.71-1.cp1198           installed
cpanel-perl-532-archive-any.noarch             0.0946-1.cp1198         installed
cpanel-perl-532-archive-any-lite.noarch        0.11-1.cp1198           installed
cpanel-perl-532-archive-extract.noarch         0.86-1.cp1198           installed
cpanel-perl-532-archive-tar-builder.x86_64     2.5005-1.cp1198         installed
cpanel-perl-532-archive-tar-stream.noarch      0.02-1.cp1198           installed
cpanel-perl-532-archive-tar-streamed.noarch    0.03-1.cp1198           installed
cpanel-perl-532-archive-tar-wrapper.noarch     0.38-1.cp1198           installed
cpanel-perl-532-archive-zip.noarch             1.68-1.cp1198           installed
cpanel-perl-532-argv-struct.noarch             0.06-1.cp1198           installed
cpanel-perl-532-array-base.x86_64              0.006-1.cp1198          installed
cpanel-perl-532-array-diff.noarch              0.09-1.cp1198           installed
cpanel-perl-532-array-utils.noarch             0.5-1.cp1198            installed
cpanel-perl-532-attribute-util.noarch          1.07-1.cp1198           installed
cpanel-perl-532-authen-libwrap.x86_64          0.23-1.cp1198           installed
cpanel-perl-532-authen-pam.x86_64              0.16-1.cp1198           installed
cpanel-perl-532-authen-sasl.noarch             2.16-1.cp1198           installed
cpanel-perl-532-autobox.x86_64                 3.0.1-1.cp1198          installed
cpanel-perl-532-autobox-core.noarch            1.33-1.cp1198           installed
cpanel-perl-532-autouse.noarch                 1.11-1.cp1198           installed
cpanel-perl-532-autovivification.x86_64        0.18-1.cp1198           installed
cpanel-perl-532-b-c.x86_64                     5.032002-1.cp1198       installed
cpanel-perl-532-b-cow.x86_64                   0.004-1.cp1198          installed
cpanel-perl-532-b-debug.noarch                 1.26-1.cp1198           installed
cpanel-perl-532-b-flags.x86_64                 0.17-1.cp1198           installed
cpanel-perl-532-b-hooks-endofscope.noarch      0.24-1.cp1198           installed
cpanel-perl-532-b-hooks-op-check.x86_64        0.22-1.cp1198           installed
cpanel-perl-532-b-keywords.noarch              1.21-1.cp1198           installed
cpanel-perl-532-b-lint.noarch                  1.20-1.cp1198           installed
cpanel-perl-532-b-utils.x86_64                 0.27-1.cp1198           installed
cpanel-perl-532-bareword-filehandles.x86_64    0.007-1.cp1198          installed
cpanel-perl-532-beam-emitter.noarch            1.007-1.cp1198          installed
cpanel-perl-532-bit-vector.x86_64              7.4-1.cp1198            installed
cpanel-perl-532-browser-open.noarch            0.04-1.cp1198           installed
cpanel-perl-532-bsd-resource.x86_64            1.2911-1.cp1198         installed
cpanel-perl-532-build-ppk.noarch               0.07-1.cp1198           installed
cpanel-perl-532-business-creditcard.noarch     0.36-1.cp1198           installed
cpanel-perl-532-business-isbn.noarch           3.005-1.cp1198          installed
cpanel-perl-532-business-isbn-data.noarch      20191107-1.cp1198       installed
cpanel-perl-532-business-maxmind.noarch        1.60-1.cp1198           installed
cpanel-perl-532-business-onlinepayment.noarch  3.05-1.cp1198           installed
cpanel-perl-532-business-onlinepayment-authorizenet.noarch
                                               3.23-1.cp1198           installed
cpanel-perl-532-business-ups.noarch            2.01-1.cp1198           installed
cpanel-perl-532-bytes-random-secure.noarch     0.29-1.cp1198           installed
cpanel-perl-532-bytes-random-secure-tiny.noarch
                                               1.011-1.cp1198          installed
cpanel-perl-532-cache-cache.noarch             1.08-1.cp1198           installed
cpanel-perl-532-cache-fastmmap.x86_64          1.50-1.cp1198           installed
cpanel-perl-532-cache-lru.noarch               0.04-1.cp1198           installed
cpanel-perl-532-cache-memcached.noarch         1.30-1.cp1198           installed
cpanel-perl-532-cache-memcached-fast.x86_64    0.26-1.cp1198           installed
cpanel-perl-532-cache-memcached-getparserxs.x86_64
                                               0.01-1.cp1198           installed
cpanel-perl-532-call-context.noarch            0.03-1.cp1198           installed
cpanel-perl-532-canary-stability.noarch        2013-1.cp1198           installed
cpanel-perl-532-capture-tiny.noarch            0.48-1.cp1198           installed
cpanel-perl-532-carp-always.noarch             0.16-1.cp1198           installed
cpanel-perl-532-carp-assert.noarch             0.21-1.cp1198           installed
cpanel-perl-532-carp-assert-more.noarch        1.24-1.cp1198           installed
cpanel-perl-532-carp-clan.noarch               6.08-1.cp1198           installed
cpanel-perl-532-carp-repl.noarch               0.18-1.cp1198           installed
cpanel-perl-532-catalyst-action-renderview.noarch
                                               0.16-1.cp1198           installed
cpanel-perl-532-catalyst-action-rest.noarch    1.21-1.cp1198           installed
cpanel-perl-532-catalyst-actionrole-acl.noarch 0.07-1.cp1198           installed
cpanel-perl-532-catalyst-authentication-store-dbix-class.noarch
                                               0.1506-1.cp1198         installed
cpanel-perl-532-catalyst-component-instancepercontext.noarch
                                               0.001001-1.cp1198       installed
cpanel-perl-532-catalyst-controller-actionrole.noarch
                                               0.17-1.cp1198           installed
cpanel-perl-532-catalyst-devel.noarch          1.42-1.cp1198           installed
cpanel-perl-532-catalyst-model-dbic-schema.noarch
                                               0.65-1.cp1198           installed
cpanel-perl-532-catalyst-plugin-authentication.noarch
                                               0.10023-1.cp1198        installed
cpanel-perl-532-catalyst-plugin-authorization-roles.noarch
                                               0.09-1.cp1198           installed
cpanel-perl-532-catalyst-plugin-autocrud.noarch
                                               2.200002-1.cp1198       installed
cpanel-perl-532-catalyst-plugin-cache.noarch   0.12-1.cp1198           installed
cpanel-perl-532-catalyst-plugin-cache-fastmmap.noarch
                                               0.9-1.cp1198            installed
cpanel-perl-532-catalyst-plugin-configloader.noarch
                                               0.35-1.cp1198           installed
cpanel-perl-532-catalyst-plugin-hashedcookies.noarch
                                               1.131710-1.cp1198       installed
cpanel-perl-532-catalyst-plugin-redirect.noarch
                                               0.02-1.cp1198           installed
cpanel-perl-532-catalyst-plugin-session.noarch 0.41-1.cp1198           installed
cpanel-perl-532-catalyst-plugin-session-state-cookie.noarch
                                               0.18-1.cp1198           installed
cpanel-perl-532-catalyst-plugin-session-store-fastmmap.noarch
                                               0.16-1.cp1198           installed
cpanel-perl-532-catalyst-plugin-stacktrace.noarch
                                               0.12-1.cp1198           installed
cpanel-perl-532-catalyst-plugin-static-simple.noarch
                                               0.36-1.cp1198           installed
cpanel-perl-532-catalyst-plugin-uploadprogress.noarch
                                               0.06-1.cp1198           installed
cpanel-perl-532-catalyst-runtime.noarch        5.90128-1.cp1198        installed
cpanel-perl-532-catalyst-traitfor-request-browserdetect.noarch
                                               0.02-1.cp1198           installed
cpanel-perl-532-catalyst-view-json.noarch      0.37-1.cp1198           installed
cpanel-perl-532-catalyst-view-tt.noarch        0.45-1.cp1198           installed
cpanel-perl-532-catalystx-component-traits.noarch
                                               0.19-1.cp1198           installed
cpanel-perl-532-catalystx-repl.noarch          0.04-1.cp1198           installed
cpanel-perl-532-catalystx-roleapplicator.noarch
                                               0.005-1.cp1198          installed
cpanel-perl-532-cbor-free.x86_64               0.31-1.cp1198           installed
cpanel-perl-532-cdb.file.x86_64                0.99-1.cp1198           installed
cpanel-perl-532-cgi.noarch                     4.51-1.cp1198           installed
cpanel-perl-532-cgi-application.noarch         4.61-1.cp1198           installed
cpanel-perl-532-cgi-application-dispatch.noarch
                                               3.12-1.cp1198           installed
cpanel-perl-532-cgi-application-plugin-autorunmode.noarch
                                               0.18-1.cp1198           installed
cpanel-perl-532-cgi-application-plugin-config-simple.noarch
                                               1.01-1.cp1198           installed
cpanel-perl-532-cgi-application-plugin-forward.noarch
                                               1.06-1.cp1198           installed
cpanel-perl-532-cgi-application-plugin-session.noarch
                                               1.05-1.cp1198           installed
cpanel-perl-532-cgi-application-plugin-tt.noarch
                                               1.05-1.cp1198           installed
cpanel-perl-532-cgi-application-plugin-validatequery.noarch
                                               1.0.5-1.cp1198          installed
cpanel-perl-532-cgi-application-plugin-validaterm.noarch
                                               2.5-1.cp1198            installed
cpanel-perl-532-cgi-application-psgi.noarch    1.00-1.cp1198           installed
cpanel-perl-532-cgi-compile.noarch             0.25-1.cp1198           installed
cpanel-perl-532-cgi-deurl-xs.x86_64            0.08-1.cp1198           installed
cpanel-perl-532-cgi-emulate-psgi.noarch        0.23-1.cp1198           installed
cpanel-perl-532-cgi-psgi.noarch                0.15-1.cp1198           installed
cpanel-perl-532-cgi-session.noarch             4.48-1.cp1198           installed
cpanel-perl-532-cgi-session-serialize-yaml.noarch
                                               4.26-1.cp1198           installed
cpanel-perl-532-cgi-simple.noarch              1.25-1.cp1198           installed
cpanel-perl-532-cgi-struct.noarch              1.21-1.cp1198           installed
cpanel-perl-532-char-replace.x86_64            0.004-1.cp1198          installed
cpanel-perl-532-chart-pnggraph.noarch          1.21-1.cp1198           installed
cpanel-perl-532-chi.noarch                     0.60-1.cp1198           installed
cpanel-perl-532-class-accessor.noarch          0.51-1.cp1198           installed
cpanel-perl-532-class-accessor-chained.noarch  0.01-1.cp1198           installed
cpanel-perl-532-class-accessor-grouped.noarch  0.10014-1.cp1198        installed
cpanel-perl-532-class-accessor-lite.noarch     0.08-1.cp1198           installed
cpanel-perl-532-class-accessor-lite-lazy.noarch
                                               0.03-1.cp1198           installed
cpanel-perl-532-class-base.noarch              0.09-1.cp1198           installed
cpanel-perl-532-class-c3.noarch                0.34-1.cp1198           installed
cpanel-perl-532-class-c3-adopt-next.noarch     0.14-1.cp1198           installed
cpanel-perl-532-class-c3-componentised.noarch  1.001002-1.cp1198       installed
cpanel-perl-532-class-data-inheritable.noarch  0.08-1.cp1198           installed
cpanel-perl-532-class-errorhandler.noarch      0.04-1.cp1198           installed
cpanel-perl-532-class-factory-util.noarch      1.7-1.cp1198            installed
cpanel-perl-532-class-inner.noarch             0.200001-1.cp1198       installed
cpanel-perl-532-class-insideout.noarch         1.14-1.cp1198           installed
cpanel-perl-532-class-inspector.noarch         1.36-1.cp1198           installed
cpanel-perl-532-class-isa.noarch               0.36-1.cp1198           installed
cpanel-perl-532-class-load.noarch              0.25-1.cp1198           installed
cpanel-perl-532-class-load-xs.x86_64           0.10-1.cp1198           installed
cpanel-perl-532-class-loader.noarch            2.03-1.cp1198           installed
cpanel-perl-532-class-measure.noarch           0.08-1.cp1198           installed
cpanel-perl-532-class-method-modifiers.noarch  2.13-1.cp1198           installed
cpanel-perl-532-class-methodmaker.x86_64       2.24-1.cp1198           installed
cpanel-perl-532-class-refresh.noarch           0.07-1.cp1198           installed
cpanel-perl-532-class-singleton.noarch         1.5-1.cp1198            installed
cpanel-perl-532-class-std.noarch               0.013-1.cp1198          installed
cpanel-perl-532-class-std-utils.noarch         0.0.3-1.cp1198          installed
cpanel-perl-532-class-tiny.noarch              1.008-1.cp1198          installed
cpanel-perl-532-class-tiny-chained.noarch      0.004-1.cp1198          installed
cpanel-perl-532-class-trigger.noarch           0.15-1.cp1198           installed
cpanel-perl-532-class-unload.noarch            0.11-1.cp1198           installed
cpanel-perl-532-class-xsaccessor.x86_64        1.19-1.cp1198           installed
cpanel-perl-532-clipboard.noarch               0.26-1.cp1198           installed
cpanel-perl-532-clone.x86_64                   0.45-1.cp1198           installed
cpanel-perl-532-clone-choose.noarch            0.010-1.cp1198          installed
cpanel-perl-532-clone-pp.noarch                1.08-1.cp1198           installed
cpanel-perl-532-colon-config.x86_64            0.004-1.cp1198          installed
cpanel-perl-532-common-sense.noarch            3.75-1.cp1198           installed
cpanel-perl-532-compiler-lexer.x86_64          0.23-1.cp1198           installed
cpanel-perl-532-compress-bzip2.x86_64          2.28-1.cp1198           installed
cpanel-perl-532-compress-raw-lzma.x86_64       2.096-1.cp1198          installed
cpanel-perl-532-config-any.noarch              0.32-1.cp1198           installed
cpanel-perl-532-config-crontab.noarch          1.45-1.cp1198           installed
cpanel-perl-532-config-general.x86_64          2.63-1.cp1198           installed
cpanel-perl-532-config-gitlike.noarch          1.18-1.cp1198           installed
cpanel-perl-532-config-identity.noarch         0.0019-1.cp1198         installed
cpanel-perl-532-config-ini.noarch              0.025-1.cp1198          installed
cpanel-perl-532-config-inifiles.noarch         3.000003-1.cp1198       installed
cpanel-perl-532-config-mvp.noarch              2.200011-1.cp1198       installed
cpanel-perl-532-config-mvp-reader-ini.noarch   2.101463-1.cp1198       installed
cpanel-perl-532-config-mvp-slicer.noarch       0.303-1.cp1198          installed
cpanel-perl-532-config-simple.noarch           4.58-1.cp1198           installed
cpanel-perl-532-config-tiny.noarch             2.24-1.cp1198           installed
cpanel-perl-532-const-fast.noarch              0.014-1.cp1198          installed
cpanel-perl-532-context-preserve.noarch        0.03-1.cp1198           installed
cpanel-perl-532-contextual-return.noarch       0.004014-1.cp1198       installed
cpanel-perl-532-convert-ascii-armour.noarch    1.4-1.cp1198            installed
cpanel-perl-532-convert-asn1.noarch            0.27-1.cp1198           installed
cpanel-perl-532-convert-base32.noarch          0.06-1.cp1198           installed
cpanel-perl-532-convert-base32-crockford.noarch
                                               0.16-1.cp1198           installed
cpanel-perl-532-convert-ber-xs.x86_64          1.21-1.cp1198           installed
cpanel-perl-532-convert-binhex.noarch          1.125-1.cp1198          installed
cpanel-perl-532-convert-pem.noarch             0.08-1.cp1198           installed
cpanel-perl-532-convert-tnef.noarch            0.18-1.cp1198           installed
cpanel-perl-532-cookie-baker.noarch            0.11-1.cp1198           installed
cpanel-perl-532-cookie-baker-xs.x86_64         0.11-1.cp1198           installed
cpanel-perl-532-coro.x86_64                    6.57-1.cp1198           installed
cpanel-perl-532-cpan-changes.noarch            0.400002-1.cp1198       installed
cpanel-perl-532-cpan-distnameinfo.noarch       0.12-1.cp1198           installed
cpanel-perl-532-cpan-meta-check.noarch         0.014-1.cp1198          installed
cpanel-perl-532-cpan-meta-requirements.noarch  2.140-1.cp1198          installed
cpanel-perl-532-cpan-perl-releases.noarch      5.20201020-1.cp1198     installed
cpanel-perl-532-cpan-sqlite.noarch             0.219-1.cp1198          installed
cpanel-perl-532-cpan-uploader.noarch           0.103015-1.cp1198       installed
cpanel-perl-532-cpanel-apiclient.noarch        0.08-1.cp1198           installed
cpanel-perl-532-cpanel-bios.x86_64             0.10-1.cp1198           installed
cpanel-perl-532-cpanel-class.x86_64            1.0.6-1.cp1198          installed
cpanel-perl-532-cpanel-cleanup.x86_64          0.4-1.cp1198            installed
cpanel-perl-532-cpanel-core-dependencies.noarch
                                               3.098007-1.cp1198       installed
cpanel-perl-532-cpanel-cpan-pkgr-builder.noarch
                                               1.17-1.cp1198           installed
cpanel-perl-532-cpanel-fastmath.x86_64         0.3-1.cp1198            installed
cpanel-perl-532-cpanel-json-xs.x86_64          4.24-1.cp1198           installed
cpanel-perl-532-cpanel-ldap.noarch             0.0041-1.cp1198         installed
cpanel-perl-532-cpanel-memtest.x86_64          0.3-1.cp1198            installed
cpanel-perl-532-cpanel-optimizer.x86_64        0.3-1.cp1198            installed
cpanel-perl-532-cpanel-posix-tiny.x86_64       1.3-1.cp1198            installed
cpanel-perl-532-cpanel-publicapi.noarch        2.8-1.cp1198            installed
cpanel-perl-532-cpanel-syncutil.noarch         0.8-1.cp1198            installed
cpanel-perl-532-cpanel-uniqid.x86_64           0.2-1.cp1198            installed
cpanel-perl-532-cpanel-xs.x86_64               0.1-1.cp1198            installed
cpanel-perl-532-cpanel-xs-rtransform.x86_64    0.05-1.cp1198           installed
cpanel-perl-532-cpanel-xslib.x86_64            0.05-1.cp1198           installed
cpanel-perl-532-cpanplus.noarch                0.9908-1.cp1198         installed
cpanel-perl-532-cpanplus-dist-build.noarch     0.90-1.cp1198           installed
cpanel-perl-532-crypt-blowfish.x86_64          2.14-1.cp1198           installed
cpanel-perl-532-crypt-cast5.pp.noarch          1.04-1.cp1198           installed
cpanel-perl-532-crypt-cbc.noarch               2.33-1.cp1198           installed
cpanel-perl-532-crypt-cracklib.x86_64          1.7-1.cp1198            installed
cpanel-perl-532-crypt-curve25519.x86_64        0.06-1.cp1198           installed
cpanel-perl-532-crypt-des.x86_64               2.07-1.cp1198           installed
cpanel-perl-532-crypt-des.ede3.noarch          0.01-1.cp1198           installed
cpanel-perl-532-crypt-dh.noarch                0.07-1.cp1198           installed
cpanel-perl-532-crypt-dsa.noarch               1.17-1.cp1198           installed
cpanel-perl-532-crypt-ed25519.x86_64           1.04-1.cp1198           installed
cpanel-perl-532-crypt-format.noarch            0.10-1.cp1198           installed
cpanel-perl-532-crypt-gpg.noarch               1.64-1.cp1198           installed
cpanel-perl-532-crypt-idea.x86_64              1.10-1.cp1198           installed
cpanel-perl-532-crypt-jwt.noarch               0.029-1.cp1198          installed
cpanel-perl-532-crypt-openpgp.noarch           1.12-1.cp1198           installed
cpanel-perl-532-crypt-openssl-bignum.x86_64    0.09-1.cp1198           installed
cpanel-perl-532-crypt-openssl-dsa.x86_64       0.19-1.cp1198           installed
cpanel-perl-532-crypt-openssl-ec.x86_64        1.32-1.cp1198           installed
cpanel-perl-532-crypt-openssl-guess.noarch     0.11-1.cp1198           installed
cpanel-perl-532-crypt-openssl-pkcs10.x86_64    0.16-1.cp1198           installed
cpanel-perl-532-crypt-openssl-pkcs12.x86_64    1.3-1.cp1198            installed
cpanel-perl-532-crypt-openssl-random.x86_64    0.15-1.cp1198           installed
cpanel-perl-532-crypt-openssl-rsa.x86_64       0.31-1.cp1198           installed
cpanel-perl-532-crypt-openssl-x509.x86_64      1.813-1.cp1198          installed
cpanel-perl-532-crypt-passwd-xs.x86_64         0.601-1.cp1198          installed
cpanel-perl-532-crypt-perl.noarch              0.34-1.cp1198           installed
cpanel-perl-532-crypt-pkcs10.noarch            2.001-1.cp1198          installed
cpanel-perl-532-crypt-primes.noarch            0.50-1.cp1198           installed
cpanel-perl-532-crypt-random.noarch            1.52-1.cp1198           installed
cpanel-perl-532-crypt-random-seed.noarch       0.03-1.cp1198           installed
cpanel-perl-532-crypt-random-source.noarch     0.14-1.cp1198           installed
cpanel-perl-532-crypt-random-tesha2.noarch     0.01-1.cp1198           installed
cpanel-perl-532-crypt-rc4.noarch               2.02-1.cp1198           installed
cpanel-perl-532-crypt-rijndael.x86_64          1.15-1.cp1198           installed
cpanel-perl-532-crypt-rijndael.pp.noarch       0.05-1.cp1198           installed
cpanel-perl-532-crypt-ripemd160.x86_64         0.08-1.cp1198           installed
cpanel-perl-532-crypt-rsa.noarch               1.99-1.cp1198           installed
cpanel-perl-532-crypt-rsa-parse.noarch         0.044-1.cp1198          installed
cpanel-perl-532-crypt-saltedhash.noarch        0.09-1.cp1198           installed
cpanel-perl-532-crypt-smbhash.noarch           0.12-1.cp1198           installed
cpanel-perl-532-crypt-ssleay.x86_64            0.73~06-1.cp1198        installed
cpanel-perl-532-crypt-twofish.x86_64           2.17-1.cp1198           installed
cpanel-perl-532-crypt-urandom.noarch           0.36-1.cp1198           installed
cpanel-perl-532-crypt-x509.noarch              0.53-1.cp1198           installed
cpanel-perl-532-cryptx.x86_64                  0.075-1.cp1198          installed
cpanel-perl-532-css.noarch                     1.09-1.cp1198           installed
cpanel-perl-532-css-simple.noarch              3224-1.cp1198           installed
cpanel-perl-532-css-spritemaker.noarch         1.01-1.cp1198           installed
cpanel-perl-532-curry.noarch                   1.001000-1.cp1198       installed
cpanel-perl-532-curses.x86_64                  1.37-1.cp1198           installed
cpanel-perl-532-curses-ui.noarch               0.9609-1.cp1198         installed
cpanel-perl-532-cwd-guard.noarch               0.05-1.cp1198           installed
cpanel-perl-532-dancer.noarch                  1.3513-1.cp1198         installed
cpanel-perl-532-dancer-plugin-database.noarch  2.13-1.cp1198           installed
cpanel-perl-532-dancer-plugin-database-core.noarch
                                               0.20-1.cp1198           installed
cpanel-perl-532-dancer2.noarch                 0.300004-1.cp1198       installed
cpanel-perl-532-dancer2-logger-console-colored.noarch
                                               0.008-1.cp1198          installed
cpanel-perl-532-dancer2-plugin-auth-extensible.noarch
                                               0.709-1.cp1198          installed
cpanel-perl-532-dancer2-plugin-auth-tiny.noarch
                                               0.008-1.cp1198          installed
cpanel-perl-532-dancer2-plugin-dbic.noarch     0.0100-1.cp1198         installed
cpanel-perl-532-dancer2-plugin-jwt.noarch      0.017-1.cp1198          installed
cpanel-perl-532-dancer2-plugin-rest.noarch     1.02-1.cp1198           installed
cpanel-perl-532-dancer2-session-cookie.noarch  0.009-1.cp1198          installed
cpanel-perl-532-dancer2-session-memcached.noarch
                                               0.007-1.cp1198          installed
cpanel-perl-532-dancer2-session-psgi.noarch    0.010-1.cp1198          installed
cpanel-perl-532-danga-socket.noarch            1.62-1.cp1198           installed
cpanel-perl-532-data-binary.noarch             0.01-1.cp1198           installed
cpanel-perl-532-data-buffer.noarch             0.04-1.cp1198           installed
cpanel-perl-532-data-compare.noarch            1.27-1.cp1198           installed
cpanel-perl-532-data-dump.noarch               1.23-1.cp1198           installed
cpanel-perl-532-data-dump-streamer.x86_64      2.40-1.cp1198           installed
cpanel-perl-532-data-dumper-concise.noarch     2.023-1.cp1198          installed
cpanel-perl-532-data-dumper-simple.noarch      0.11-1.cp1198           installed
cpanel-perl-532-data-formvalidator.noarch      4.88-1.cp1198           installed
cpanel-perl-532-data-formvalidator-constraints-creditcard.noarch
                                               0.02-1.cp1198           installed
cpanel-perl-532-data-localize.noarch           0.00028-1.cp1198        installed
cpanel-perl-532-data-messagepack.x86_64        1.01-1.cp1198           installed
cpanel-perl-532-data-munge.noarch              0.097-1.cp1198          installed
cpanel-perl-532-data-optlist.noarch            0.110-1.cp1198          installed
cpanel-perl-532-data-page.noarch               2.03-1.cp1198           installed
cpanel-perl-532-data-password.noarch           1.12-1.cp1198           installed
cpanel-perl-532-data-perl.noarch               0.002011-1.cp1198       installed
cpanel-perl-532-data-printer.noarch            0.40-1.cp1198           installed
cpanel-perl-532-data-random.noarch             0.13-1.cp1198           installed
cpanel-perl-532-data-rmap.noarch               0.65-1.cp1198           installed
cpanel-perl-532-data-section.noarch            0.200007-1.cp1198       installed
cpanel-perl-532-data-serializer.noarch         0.65-1.cp1198           installed
cpanel-perl-532-data-structure-util.x86_64     0.16-1.cp1198           installed
cpanel-perl-532-data-util.x86_64               0.66-1.cp1198           installed
cpanel-perl-532-data-uuid.x86_64               1.226-1.cp1198          installed
cpanel-perl-532-data-validate.noarch           0.09-1.cp1198           installed
cpanel-perl-532-data-validate-domain.noarch    0.14-1.cp1198           installed
cpanel-perl-532-data-validate-ip.noarch        0.27-1.cp1198           installed
cpanel-perl-532-data-validate-uri.noarch       0.07-1.cp1198           installed
cpanel-perl-532-data-validator.noarch          1.07-1.cp1198           installed
cpanel-perl-532-data-visitor.noarch            0.31-1.cp1198           installed
cpanel-perl-532-date-calc.noarch               6.4-1.cp1198            installed
cpanel-perl-532-date-simple.x86_64             3.03-1.cp1198           installed
cpanel-perl-532-datetime.x86_64                1.52-1.cp1198           installed
cpanel-perl-532-datetime-format-builder.noarch 0.83-1.cp1198           installed
cpanel-perl-532-datetime-format-dateparse.noarch
                                               0.05-1.cp1198           installed
cpanel-perl-532-datetime-format-iso8601.noarch 0.15-1.cp1198           installed
cpanel-perl-532-datetime-format-mail.noarch    0.403-1.cp1198          installed
cpanel-perl-532-datetime-format-mysql.noarch   0.06-1.cp1198           installed
cpanel-perl-532-datetime-format-pg.noarch      0.16013-1.cp1198        installed
cpanel-perl-532-datetime-format-rfc3339.noarch 1.2.0-1.cp1198          installed
cpanel-perl-532-datetime-format-strptime.noarch
                                               1.77-1.cp1198           installed
cpanel-perl-532-datetime-locale.noarch         1.28-1.cp1198           installed
cpanel-perl-532-datetime-timezone.noarch       2.43-1.cp1198           installed
cpanel-perl-532-dbd-mock.noarch                1.58-1.cp1198           installed
cpanel-perl-532-dbd-mysql.x86_64               4.050-1.cp1198          installed
cpanel-perl-532-dbd-pg.x86_64                  3.14.2-1.cp1198         installed
cpanel-perl-532-dbd-pgpp.noarch                0.08-1.cp1198           installed
cpanel-perl-532-dbd-sqlite.x86_64              1.66-1.cp1198           installed
cpanel-perl-532-dbd-sqlite2.x86_64             0.38-1.cp1198           installed
cpanel-perl-532-dbi.x86_64                     1.643-1.cp1198          installed
cpanel-perl-532-dbicx-sugar.noarch             0.0200-1.cp1198         installed
cpanel-perl-532-dbix-class.noarch              0.082842-1.cp1198       installed
cpanel-perl-532-dbix-class-inflatecolumn-serializer.noarch
                                               0.09-1.cp1198           installed
cpanel-perl-532-dbix-class-introspectablem2m.noarch
                                               0.001002-1.cp1198       installed
cpanel-perl-532-dbix-class-schema-loader.noarch
                                               0.07049-1.cp1198        installed
cpanel-perl-532-dbix-myparsepp.noarch          0.51-1.cp1198           installed
cpanel-perl-532-dbix-profile.noarch            1.0-1.cp1198            installed
cpanel-perl-532-dbix-timeout.noarch            1.01-1.cp1198           installed
cpanel-perl-532-devel-callchecker.x86_64       0.008-1.cp1198          installed
cpanel-perl-532-devel-caller.x86_64            2.06-1.cp1198           installed
cpanel-perl-532-devel-callparser.x86_64        0.002-1.cp1198          installed
cpanel-perl-532-devel-checkbin.noarch          0.04-1.cp1198           installed
cpanel-perl-532-devel-checkcompiler.noarch     0.07-1.cp1198           installed
cpanel-perl-532-devel-checklib.x86_64          1.14-1.cp1198           installed
cpanel-perl-532-devel-checkos.noarch           1.85-1.cp1198           installed
cpanel-perl-532-devel-countops.x86_64          0.01-1.cp1198           installed
cpanel-perl-532-devel-cover.x86_64             1.36-1.cp1198           installed
cpanel-perl-532-devel-cover-report-coveralls.noarch
                                               0.15-1.cp1198           installed
cpanel-perl-532-devel-cover-report-sonargeneric.noarch
                                               0.7-1.cp1198            installed
cpanel-perl-532-devel-cycle.noarch             1.12-1.cp1198           installed
cpanel-perl-532-devel-findperl.noarch          0.015-1.cp1198          installed
cpanel-perl-532-devel-globaldestruction.noarch 0.14-1.cp1198           installed
cpanel-perl-532-devel-globaldestruction-xs.x86_64
                                               0.03-1.cp1198           installed
cpanel-perl-532-devel-globalphase.noarch       0.003003-1.cp1198       installed
cpanel-perl-532-devel-hide.noarch              0.0013-1.cp1198         installed
cpanel-perl-532-devel-leak.x86_64              0.03-1.cp1198           installed
cpanel-perl-532-devel-lexalias.x86_64          0.05-1.cp1198           installed
cpanel-perl-532-devel-nytprof.x86_64           6.06-1.cp1198           installed
cpanel-perl-532-devel-overloadinfo.noarch      0.005-1.cp1198          installed
cpanel-perl-532-devel-overrideglobalrequire.noarch
                                               0.001-1.cp1198          installed
cpanel-perl-532-devel-patchperl.x86_64         2.00-1.cp1198           installed
cpanel-perl-532-devel-ppport.x86_64            3.54-1.cp1198           installed
cpanel-perl-532-devel-quickcover.x86_64        0.900014-1.cp1198       installed
cpanel-perl-532-devel-repl.noarch              1.003028-1.cp1198       installed
cpanel-perl-532-devel-simpletrace.noarch       0.08-1.cp1198           installed
cpanel-perl-532-devel-size.x86_64              0.83-1.cp1198           installed
cpanel-perl-532-devel-stacktrace.noarch        2.04-1.cp1198           installed
cpanel-perl-532-devel-stacktrace-ashtml.noarch 0.15-1.cp1198           installed
cpanel-perl-532-devel-stacktrace-withlexicals.noarch
                                               2.01-1.cp1198           installed
cpanel-perl-532-devel-symdump.noarch           2.18-1.cp1198           installed
cpanel-perl-532-devel-trace.noarch             0.12-1.cp1198           installed
cpanel-perl-532-devel-traceuse.noarch          2.096-1.cp1198          installed
cpanel-perl-532-diff-libxdiff.x86_64           0.05-1.cp1198           installed
cpanel-perl-532-digest-bubblebabble.noarch     0.02-1.cp1198           installed
cpanel-perl-532-digest-fnv.x86_64              2.00-1.cp1198           installed
cpanel-perl-532-digest-hmac.noarch             1.03-1.cp1198           installed
cpanel-perl-532-digest-jhash.x86_64            0.10-1.cp1198           installed
cpanel-perl-532-digest-md2.x86_64              2.04-1.cp1198           installed
cpanel-perl-532-digest-md4.x86_64              1.9-1.cp1198            installed
cpanel-perl-532-digest-md5-file.noarch         0.08-1.cp1198           installed
cpanel-perl-532-digest-murmurhash.x86_64       0.11-1.cp1198           installed
cpanel-perl-532-digest-perl-md5.noarch         1.9-1.cp1198            installed
cpanel-perl-532-digest-sha1.x86_64             2.13-1.cp1198           installed
cpanel-perl-532-directory-queue.noarch         2.0-1.cp1198            installed
cpanel-perl-532-dist-checkconflicts.noarch     0.11-1.cp1198           installed
cpanel-perl-532-dist-zilla.noarch              6.017-1.cp1198          installed
cpanel-perl-532-dist-zilla-app-command-regenerate.noarch
                                               0.001001-1.cp1198       installed
cpanel-perl-532-dist-zilla-config-slicer.noarch
                                               0.202-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-authority.noarch
                                               1.009-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-autometaresources.noarch
                                               1.21-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-bumpversionafterrelease.noarch
                                               0.018-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-checkchangelog.noarch
                                               0.05-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-checkchangeshascontent.noarch
                                               0.011-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-checkextratests.noarch
                                               0.029-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-checkissues.noarch
                                               0.011-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-checkmetaresources.noarch
                                               0.001-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-checkprereqsindexed.noarch
                                               0.020-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-checkselfdependency.noarch
                                               0.011-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-checkstrictversion.noarch
                                               0.001-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-config-git.noarch
                                               0.92-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-copyfilesfromrelease.noarch
                                               0.007-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-ensurelatestperl.noarch
                                               0.008-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-generatefile-fromsharedir.noarch
                                               0.014-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-git.noarch   2.047-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-git-contributors.noarch
                                               0.035-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-git-describe.noarch
                                               0.007-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-git-pushinitial.noarch
                                               0.02-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-git-remote-check.noarch
                                               0.1.2-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-github.noarch
                                               0.47-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-githubmeta.noarch
                                               0.58-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-installguide.noarch
                                               1.200013-1.cp1198       installed
cpanel-perl-532-dist-zilla-plugin-keywords.noarch
                                               0.007-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-makemaker-awesome.noarch
                                               0.48-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-makemaker-fallback.noarch
                                               0.030-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-metamergefile.noarch
                                               0.004-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-metaprovides.noarch
                                               2.002004-1.cp1198       installed
cpanel-perl-532-dist-zilla-plugin-metaprovides-package.noarch
                                               2.004003-1.cp1198       installed
cpanel-perl-532-dist-zilla-plugin-minimumperl.noarch
                                               1.006-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-modulebuildtiny.noarch
                                               0.015-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-modulebuildtiny-fallback.noarch
                                               0.025-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-mojibaketests.noarch
                                               0.8-1.cp1198            installed
cpanel-perl-532-dist-zilla-plugin-perltidy.noarch
                                               0.21-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-pod2readme.noarch
                                               0.004-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-podweaver.noarch
                                               4.008-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-prereqs-authordeps.noarch
                                               0.007-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-prereqs-fromcpanfile.noarch
                                               0.08-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-promptifstale.noarch
                                               0.057-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-readmeanyfrompod.noarch
                                               0.163250-1.cp1198       installed
cpanel-perl-532-dist-zilla-plugin-repository.noarch
                                               0.24-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-rewriteversion-transitional.noarch
                                               0.009-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-run.noarch   0.048-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-staticinstall.noarch
                                               0.012-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-test-cleannamespaces.noarch
                                               0.006-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-test-compile.noarch
                                               2.058-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-test-cpan-changes.noarch
                                               0.012-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-test-eol.noarch
                                               0.19-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-test-kwalitee.noarch
                                               2.12-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-test-minimumversion.noarch
                                               2.000010-1.cp1198       installed
cpanel-perl-532-dist-zilla-plugin-test-notabs.noarch
                                               0.15-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-test-perl-critic.noarch
                                               3.001-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-test-pod-coverage-configurable.noarch
                                               0.07-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-test-pod-no404s.noarch
                                               1.004-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-test-podspelling.noarch
                                               2.007005-1.cp1198       installed
cpanel-perl-532-dist-zilla-plugin-test-portability.noarch
                                               2.001000-1.cp1198       installed
cpanel-perl-532-dist-zilla-plugin-test-reportprereqs.noarch
                                               0.028-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-test-version.noarch
                                               1.09-1.cp1198           installed
cpanel-perl-532-dist-zilla-plugin-useunsafeinc.noarch
                                               0.001-1.cp1198          installed
cpanel-perl-532-dist-zilla-plugin-versionfrommainmodule.noarch
                                               0.04-1.cp1198           installed
cpanel-perl-532-dist-zilla-pluginbundle-author-dbook.noarch
                                               1.0.4-1.cp1198          installed
cpanel-perl-532-dist-zilla-pluginbundle-author-ether.noarch
                                               0.158-1.cp1198          installed
cpanel-perl-532-dist-zilla-pluginbundle-git-checkfor.noarch
                                               0.014-1.cp1198          installed
cpanel-perl-532-dist-zilla-pluginbundle-git-versionmanager.noarch
                                               0.007-1.cp1198          installed
cpanel-perl-532-dist-zilla-pluginbundle-starter.noarch
                                               4.0.1-1.cp1198          installed
cpanel-perl-532-dist-zilla-pluginbundle-starter-git.noarch
                                               4.0.0-1.cp1198          installed
cpanel-perl-532-dist-zilla-role-filewatcher.noarch
                                               0.006-1.cp1198          installed
cpanel-perl-532-dist-zilla-role-modulemetadata.noarch
                                               0.006-1.cp1198          installed
cpanel-perl-532-dist-zilla-role-pluginbundle-pluginremover.noarch
                                               0.105-1.cp1198          installed
cpanel-perl-532-dist-zilla-role-repofileinjector.noarch
                                               0.009-1.cp1198          installed
cpanel-perl-532-dns-ldns.x86_64                0.61-2.cp1198           installed
cpanel-perl-532-dns-unbound.x86_64             0.27-1.cp1198           installed
cpanel-perl-532-dumbbench.noarch               0.111-1.cp1198          installed
cpanel-perl-532-dynaloader-functions.x86_64    0.003-1.cp1198          installed
cpanel-perl-532-email-abstract.noarch          3.008-1.cp1198          installed
cpanel-perl-532-email-address.noarch           1.912-1.cp1198          installed
cpanel-perl-532-email-address-xs.x86_64        1.04-1.cp1198           installed
cpanel-perl-532-email-date-format.noarch       1.005-1.cp1198          installed
cpanel-perl-532-email-messageid.noarch         1.406-1.cp1198          installed
cpanel-perl-532-email-mime.noarch              1.949-1.cp1198          installed
cpanel-perl-532-email-mime-contenttype.noarch  1.024-1.cp1198          installed
cpanel-perl-532-email-mime-encodings.noarch    1.315-1.cp1198          installed
cpanel-perl-532-email-send.noarch              2.201-1.cp1198          installed
cpanel-perl-532-email-sender.noarch            1.300035-1.cp1198       installed
cpanel-perl-532-email-simple.noarch            2.216-1.cp1198          installed
cpanel-perl-532-email-valid.noarch             1.202-1.cp1198          installed
cpanel-perl-532-encode.x86_64                  3.12-3.cp1198           installed
cpanel-perl-532-encode-detect.x86_64           1.01-1.cp1198           installed
cpanel-perl-532-encode-locale.noarch           1.05-1.cp1198           installed
cpanel-perl-532-encoding-ber.noarch            1.02-1.cp1198           installed
cpanel-perl-532-env-path.noarch                0.19-1.cp1198           installed
cpanel-perl-532-error.noarch                   0.17029-1.cp1198        installed
cpanel-perl-532-eval-closure.noarch            0.14-1.cp1198           installed
cpanel-perl-532-exception-class.noarch         1.44-1.cp1198           installed
cpanel-perl-532-exception-tiny.noarch          0.2.1-1.cp1198          installed
cpanel-perl-532-expect.noarch                  1.35-1.cp1198           installed
cpanel-perl-532-expect-simple.noarch           0.04-1.cp1198           installed
cpanel-perl-532-exporter-declare.noarch        0.114-1.cp1198          installed
cpanel-perl-532-exporter-lite.noarch           0.08-1.cp1198           installed
cpanel-perl-532-exporter-tiny.noarch           1.002002-1.cp1198       installed
cpanel-perl-532-extutils-config.noarch         0.008-1.cp1198          installed
cpanel-perl-532-extutils-depends.noarch        0.8000-1.cp1198         installed
cpanel-perl-532-extutils-helpers.noarch        0.026-1.cp1198          installed
cpanel-perl-532-extutils-installpaths.noarch   0.012-1.cp1198          installed
cpanel-perl-532-extutils-makemaker-cpanfile.noarch
                                               0.09-1.cp1198           installed
cpanel-perl-532-extutils-pkgconfig.noarch      1.16-1.cp1198           installed
cpanel-perl-532-fcgi.x86_64                    0.79-1.cp1198           installed
cpanel-perl-532-fcgi-procmanager.noarch        0.28-1.cp1198           installed
cpanel-perl-532-fennec-lite.noarch             0.004-1.cp1198          installed
cpanel-perl-532-ffi-checklib.noarch            0.27-1.cp1198           installed
cpanel-perl-532-ffi-platypus.x86_64            1.34-1.cp1198           installed
cpanel-perl-532-ffi-raw.x86_64                 0.32-1.cp1198           installed
cpanel-perl-532-file-basedir.noarch            0.08-1.cp1198           installed
cpanel-perl-532-file-changenotify.noarch       0.31-1.cp1198           installed
cpanel-perl-532-file-chdir.noarch              0.1010-1.cp1198         installed
cpanel-perl-532-file-checktree.noarch          4.42-1.cp1198           installed
cpanel-perl-532-file-comments.x86_64           0.08-1.cp1198           installed
cpanel-perl-532-file-copy-recursive.noarch     0.45-1.cp1198           installed
cpanel-perl-532-file-copy-recursive-reduced.noarch
                                               0.006-1.cp1198          installed
cpanel-perl-532-file-desktopentry.noarch       0.22-1.cp1198           installed
cpanel-perl-532-file-fcntllock.x86_64          0.22-1.cp1198           installed
cpanel-perl-532-file-find-object.noarch        0.3.5-1.cp1198          installed
cpanel-perl-532-file-find-rule.noarch          0.34-1.cp1198           installed
cpanel-perl-532-file-find-rule-filesys-virtual.noarch
                                               1.22-1.cp1198           installed
cpanel-perl-532-file-find-rule-perl.noarch     1.15-1.cp1198           installed
cpanel-perl-532-file-find-upwards.noarch       1.102030-1.cp1198       installed
cpanel-perl-532-file-fnmatch.x86_64            0.02-1.cp1198           installed
cpanel-perl-532-file-homedir.noarch            1.006-1.cp1198          installed
cpanel-perl-532-file-listing.noarch            6.11-1.cp1198           installed
cpanel-perl-532-file-mimeinfo.noarch           0.30-1.cp1198           installed
cpanel-perl-532-file-mmagic.noarch             1.30-1.cp1198           installed
cpanel-perl-532-file-mmagic-xs.x86_64          0.09008-1.cp1198        installed
cpanel-perl-532-file-next.x86_64               1.18-1.cp1198           installed
cpanel-perl-532-file-nfslock.noarch            1.29-1.cp1198           installed
cpanel-perl-532-file-path-expand.noarch        1.02-1.cp1198           installed
cpanel-perl-532-file-path-tiny.noarch          1.0-1.cp1198            installed
cpanel-perl-532-file-pathlist.noarch           1.04-1.cp1198           installed
cpanel-perl-532-file-pushd.noarch              1.016-1.cp1198          installed
cpanel-perl-532-file-readbackwards.noarch      1.05-1.cp1198           installed
cpanel-perl-532-file-remove.noarch             1.60-1.cp1198           installed
cpanel-perl-532-file-rename.noarch             1.13-1.cp1198           installed
cpanel-perl-532-file-rsync.noarch              0.49-1.cp1198           installed
cpanel-perl-532-file-scan-clamav.noarch        1.95-2.cp1198           installed
cpanel-perl-532-file-searchpath.noarch         0.07-1.cp1198           installed
cpanel-perl-532-file-share.noarch              0.25-1.cp1198           installed
cpanel-perl-532-file-sharedir.noarch           1.118-1.cp1198          installed
cpanel-perl-532-file-sharedir-install.noarch   0.13-1.cp1198           installed
cpanel-perl-532-file-sharedir-projectdistdir.noarch
                                               1.000009-1.cp1198       installed
cpanel-perl-532-file-slurp.noarch              9999.32-1.cp1198        installed
cpanel-perl-532-file-slurp-tiny.noarch         0.004-1.cp1198          installed
cpanel-perl-532-file-slurper.noarch            0.012-1.cp1198          installed
cpanel-perl-532-file-slurper-temp.noarch       0.006-1.cp1198          installed
cpanel-perl-532-file-tail.noarch               1.3-1.cp1198            installed
cpanel-perl-532-file-temp.noarch               0.2311-1.cp1198         installed
cpanel-perl-532-file-touch.noarch              0.11-1.cp1198           installed
cpanel-perl-532-file-which.noarch              1.23-1.cp1198           installed
cpanel-perl-532-filesys-df.x86_64              0.92-1.cp1198           installed
cpanel-perl-532-filesys-notify-simple.noarch   0.14-1.cp1198           installed
cpanel-perl-532-filesys-posix.noarch           0.9.19-1.cp1198         installed
cpanel-perl-532-filesys-statvfs.x86_64         0.82-1.cp1198           installed
cpanel-perl-532-filesys-virtual.noarch         0.06-1.cp1198           installed
cpanel-perl-532-filesys-virtual-plain.noarch   0.10-1.cp1198           installed
cpanel-perl-532-filter.x86_64                  1.60-1.cp1198           installed
cpanel-perl-532-findbin-libs.noarch            2.019002-1.cp1198       installed
cpanel-perl-532-font-afm.noarch                1.20-1.cp1198           installed
cpanel-perl-532-font-ttf.noarch                1.06-1.cp1198           installed
cpanel-perl-532-forks.x86_64                   0.36-1.cp1198           installed
cpanel-perl-532-frontier-rpc.noarch            0.07-1.cp1198           installed
cpanel-perl-532-furl.noarch                    3.13-1.cp1198           installed
cpanel-perl-532-gd.x86_64                      2.73-1.cp1198           installed
cpanel-perl-532-gd-securityimage.noarch        1.75-1.cp1198           installed
cpanel-perl-532-gdgraph.noarch                 1.54-1.cp1198           installed
cpanel-perl-532-gdtextutil.noarch              0.86-1.cp1198           installed
cpanel-perl-532-gearman.noarch                 2.4.15-1.cp1198         installed
cpanel-perl-532-geo-distance.noarch            0.24-1.cp1198           installed
cpanel-perl-532-geo-ip.x86_64                  1.51-1.cp1198           installed
cpanel-perl-532-geo-ipfree.noarch              1.151940-2.cp1198       installed
cpanel-perl-532-geography-countries.noarch     2009041301-1.cp1198     installed
cpanel-perl-532-getopt-euclid.noarch           0.004005-1.cp1198       installed
cpanel-perl-532-getopt-long-descriptive.noarch 0.105-1.cp1198          installed
cpanel-perl-532-getopt-param.noarch            0.0.5-1.cp1198          installed
cpanel-perl-532-getopt-param-tiny.noarch       0.5-1.cp1198            installed
cpanel-perl-532-gifgraph.noarch                1.20-1.cp1198           installed
cpanel-perl-532-gis-distance.noarch            0.18-1.cp1198           installed
cpanel-perl-532-git-raw.x86_64                 0.87-1.cp1198           installed
cpanel-perl-532-git-repository.noarch          1.324-1.cp1198          installed
cpanel-perl-532-git-repository-plugin-dirty.noarch
                                               0.01-1.cp1198           installed
cpanel-perl-532-git-version-compare.noarch     1.004-1.cp1198          installed
cpanel-perl-532-git-wrapper.noarch             0.048-1.cp1198          installed
cpanel-perl-532-goto-file.noarch               0.005-1.cp1198          installed
cpanel-perl-532-graph-easy.noarch              0.76-1.cp1198           installed
cpanel-perl-532-graph-easy-as.svg.noarch       0.28-1.cp1198           installed
cpanel-perl-532-graph-easy-manual.noarch       0.41-1.cp1198           installed
cpanel-perl-532-graph-flowchart.noarch         0.11-1.cp1198           installed
cpanel-perl-532-gssapi.x86_64                  0.28-1.cp1198           installed
cpanel-perl-532-guard.x86_64                   1.023-1.cp1198          installed
cpanel-perl-532-hash-asobject.noarch           0.13-1.cp1198           installed
cpanel-perl-532-hash-flatten.noarch            1.19-1.cp1198           installed
cpanel-perl-532-hash-merge.noarch              0.302-1.cp1198          installed
cpanel-perl-532-hash-merge-simple.noarch       0.051-1.cp1198          installed
cpanel-perl-532-hash-moreutils.noarch          0.06-1.cp1198           installed
cpanel-perl-532-hash-multivalue.noarch         0.16-1.cp1198           installed
cpanel-perl-532-hash-util-fieldhash-compat.noarch
                                               0.11-1.cp1198           installed
cpanel-perl-532-hook-lexwrap.noarch            0.26-1.cp1198           installed
cpanel-perl-532-html-fillinform.noarch         2.21-1.cp1198           installed
cpanel-perl-532-html-fillinform-lite.noarch    1.15-1.cp1198           installed
cpanel-perl-532-html-form.noarch               6.07-1.cp1198           installed
cpanel-perl-532-html-formatter.noarch          2.16-1.cp1198           installed
cpanel-perl-532-html-parser.x86_64             3.75-1.cp1198           installed
cpanel-perl-532-html-scrubber.noarch           0.19-1.cp1198           installed
cpanel-perl-532-html-striptags.noarch          1.01-1.cp1198           installed
cpanel-perl-532-html-tagset.noarch             3.20-1.cp1198           installed
cpanel-perl-532-html-template.noarch           2.97-1.cp1198           installed
cpanel-perl-532-html-tree.noarch               5.07-1.cp1198           installed
cpanel-perl-532-html-treebuilder-xpath.noarch  0.14-1.cp1198           installed
cpanel-perl-532-http-body.noarch               1.22-1.cp1198           installed
cpanel-perl-532-http-browserdetect.noarch      3.31-1.cp1198           installed
cpanel-perl-532-http-cookiejar.noarch          0.010-1.cp1198          installed
cpanel-perl-532-http-cookies.noarch            6.08-1.cp1198           installed
cpanel-perl-532-http-daemon.noarch             6.12-1.cp1198           installed
cpanel-perl-532-http-daemon-app.noarch         0.0.9-1.cp1198          installed
cpanel-perl-532-http-daemon-ssl.noarch         1.04-1.cp1198           installed
cpanel-perl-532-http-date.noarch               6.05-1.cp1198           installed
cpanel-perl-532-http-dav.noarch                0.49-1.cp1198           installed
cpanel-perl-532-http-entity-parser.noarch      0.24-1.cp1198           installed
cpanel-perl-532-http-exception.noarch          0.04007-1.cp1198        installed
cpanel-perl-532-http-headers-fast.noarch       0.22-1.cp1198           installed
cpanel-perl-532-http-message.noarch            6.26-1.cp1198           installed
cpanel-perl-532-http-multipartparser.noarch    0.02-1.cp1198           installed
cpanel-perl-532-http-negotiate.noarch          6.01-1.cp1198           installed
cpanel-perl-532-http-parser-xs.x86_64          0.17-1.cp1198           installed
cpanel-perl-532-http-request-ascgi.noarch      1.2-1.cp1198            installed
cpanel-perl-532-http-response-cgi.noarch       1.0-1.cp1198            installed
cpanel-perl-532-http-response-stringable.noarch
                                               0.0002-1.cp1198         installed
cpanel-perl-532-http-server-simple.noarch      0.52-1.cp1198           installed
cpanel-perl-532-http-server-simple-psgi.noarch 0.16-1.cp1198           installed
cpanel-perl-532-http-serverevent.noarch        0.02-1.cp1198           installed
cpanel-perl-532-http-thin.noarch               0.006-1.cp1198          installed
cpanel-perl-532-http-tiny-mech.noarch          1.001002-1.cp1198       installed
cpanel-perl-532-http-tiny-ua.noarch            0.006-1.cp1198          installed
cpanel-perl-532-http-xscookies.x86_64          0.000021-1.cp1198       installed
cpanel-perl-532-http-xsheaders.x86_64          0.400004-1.cp1198       installed
cpanel-perl-532-image-base.noarch              1.17-1.cp1198           installed
cpanel-perl-532-image-info.noarch              1.42-1.cp1198           installed
cpanel-perl-532-image-size.noarch              3.300-1.cp1198          installed
cpanel-perl-532-image-xbm.noarch               1.10-1.cp1198           installed
cpanel-perl-532-image-xpm.noarch               1.13-1.cp1198           installed
cpanel-perl-532-import-into.noarch             1.002005-1.cp1198       installed
cpanel-perl-532-importer.noarch                0.026-1.cp1198          installed
cpanel-perl-532-indirect.x86_64                0.39-1.cp1198           installed
cpanel-perl-532-inline.noarch                  0.86-1.cp1198           installed
cpanel-perl-532-inline-python.x86_64           0.56-1.cp1198           installed
cpanel-perl-532-io-aio.x86_64                  4.72-1.cp1198           installed
cpanel-perl-532-io-all.noarch                  0.87-1.cp1198           installed
cpanel-perl-532-io-callback.noarch             2.00-1.cp1198           installed
cpanel-perl-532-io-capture.noarch              0.05-1.cp1198           installed
cpanel-perl-532-io-captureoutput.noarch        1.1105-1.cp1198         installed
cpanel-perl-532-io-closefds.x86_64             1.01-1.cp1198           installed
cpanel-perl-532-io-fdpass.x86_64               1.2-1.cp1198            installed
cpanel-perl-532-io-framed.noarch               0.16-1.cp1198           installed
cpanel-perl-532-io-html.noarch                 1.004-1.cp1198          installed
cpanel-perl-532-io-interactive.noarch          1.022-1.cp1198          installed
cpanel-perl-532-io-interactive-tiny.noarch     0.2-1.cp1198            installed
cpanel-perl-532-io-interface.x86_64            1.09-1.cp1198           installed
cpanel-perl-532-io-pipely.noarch               0.005-1.cp1198          installed
cpanel-perl-532-io-prompt.noarch               0.997004-1.cp1198       installed
cpanel-perl-532-io-prompter.noarch             0.004015-1.cp1198       installed
cpanel-perl-532-io-sessiondata.noarch          1.03-1.cp1198           installed
cpanel-perl-532-io-sigguard.noarch             0.15-1.cp1198           installed
cpanel-perl-532-io-socket-bytecounter.noarch   0.3-1.cp1198            installed
cpanel-perl-532-io-socket-inet6.noarch         2.72-1.cp1198           installed
cpanel-perl-532-io-socket-ip.noarch            0.41-1.cp1198           installed
cpanel-perl-532-io-socket-portstate.noarch     0.03-1.cp1198           installed
cpanel-perl-532-io-socket-ssl.noarch           2.068-1.cp1198          installed
cpanel-perl-532-io-socket-timeout.noarch       0.32-1.cp1198           installed
cpanel-perl-532-io-string.noarch               1.08-1.cp1198           installed
cpanel-perl-532-io-stringy.noarch              2.113-1.cp1198          installed
cpanel-perl-532-io-stty.noarch                 0.04-1.cp1198           installed
cpanel-perl-532-io-tiecombine.noarch           1.005-1.cp1198          installed
cpanel-perl-532-io-tty.x86_64                  1.15-1.cp1198           installed
cpanel-perl-532-io-uncompress-untar.noarch     1.02-1.cp1198           installed
cpanel-perl-532-ip-country.noarch              2.28-1.cp1198           installed
cpanel-perl-532-ipc-open3-utils.noarch         0.92-1.cp1198           installed
cpanel-perl-532-ipc-pipeline.noarch            1.0-1.cp1198            installed
cpanel-perl-532-ipc-run.noarch                 20200505.0-1.cp1198     installed
cpanel-perl-532-ipc-run3.noarch                0.048-1.cp1198          installed
cpanel-perl-532-ipc-sharelite.x86_64           0.17-1.cp1198           installed
cpanel-perl-532-ipc-signal.noarch              1.00-1.cp1198           installed
cpanel-perl-532-ipc-system-simple.noarch       1.30-1.cp1198           installed
cpanel-perl-532-javascript-minifier.noarch     1.14-1.cp1198           installed
cpanel-perl-532-jira-rest.noarch               0.020-1.cp1198          installed
cpanel-perl-532-json.noarch                    4.02-1.cp1198           installed
cpanel-perl-532-json-any.noarch                1.39-1.cp1198           installed
cpanel-perl-532-json-dwiw.x86_64               0.47-1.cp1198           installed
cpanel-perl-532-json-maybexs.noarch            1.004002-1.cp1198       installed
cpanel-perl-532-json-webtoken.noarch           0.10-1.cp1198           installed
cpanel-perl-532-json-xs.x86_64                 4.03-1.cp1198           installed
cpanel-perl-532-lchown.x86_64                  1.01-1.cp1198           installed
cpanel-perl-532-lexical-persistence.noarch     1.023-1.cp1198          installed
cpanel-perl-532-lexical-sealrequirehints.x86_64
                                               0.011-1.cp1198          installed
cpanel-perl-532-lib-restrict.noarch            0.0.5-1.cp1198          installed
cpanel-perl-532-libwww-perl.noarch             6.49-1.cp1198           installed
cpanel-perl-532-libxml-perl.noarch             0.08-1.cp1198           installed
cpanel-perl-532-lingua-en-findnumber.noarch    1.32-1.cp1198           installed
cpanel-perl-532-lingua-en-inflect.noarch       1.904-1.cp1198          installed
cpanel-perl-532-lingua-en-inflect-number.noarch
                                               1.12-1.cp1198           installed
cpanel-perl-532-lingua-en-inflect-phrase.noarch
                                               0.20-1.cp1198           installed
cpanel-perl-532-lingua-en-number-isordinal.noarch
                                               0.05-1.cp1198           installed
cpanel-perl-532-lingua-en-tagger.noarch        0.31-1.cp1198           installed
cpanel-perl-532-lingua-en-words2nums.noarch    0.18-1.cp1198           installed
cpanel-perl-532-lingua-pt-stemmer.noarch       0.02-1.cp1198           installed
cpanel-perl-532-lingua-stem.noarch             2.31-1.cp1198           installed
cpanel-perl-532-lingua-stem-fr.noarch          0.02-1.cp1198           installed
cpanel-perl-532-lingua-stem-it.noarch          0.02-1.cp1198           installed
cpanel-perl-532-lingua-stem-ru.noarch          0.04-1.cp1198           installed
cpanel-perl-532-lingua-stem-snowball-da.noarch 1.01-1.cp1198           installed
cpanel-perl-532-linux-ext2-fileattributes.noarch
                                               0.01-1.cp1198           installed
cpanel-perl-532-linux-inotify2.x86_64          2.2-1.cp1198            installed
cpanel-perl-532-linux-systemd.x86_64           1.201600-1.cp1198       installed
cpanel-perl-532-list-allutils.noarch           0.18-1.cp1198           installed
cpanel-perl-532-list-cycle.noarch              1.02-1.cp1198           installed
cpanel-perl-532-list-moreutils.noarch          0.430-1.cp1198          installed
cpanel-perl-532-list-moreutils-xs.x86_64       0.430-1.cp1198          installed
cpanel-perl-532-list-someutils.noarch          0.58-1.cp1198           installed
cpanel-perl-532-list-someutils-xs.x86_64       0.58-1.cp1198           installed
cpanel-perl-532-list-utilsby.noarch            0.11-1.cp1198           installed
cpanel-perl-532-local-lib.noarch               2.000024-1.cp1198       installed
cpanel-perl-532-locale-currency-format.noarch  1.35-1.cp1198           installed
cpanel-perl-532-locale-maketext-pseudo.noarch  0.6-1.cp1198            installed
cpanel-perl-532-locale-maketext-utils.noarch   0.42-1.cp1198           installed
cpanel-perl-532-locale-object.noarch           0.80-1.cp1198           installed
cpanel-perl-532-locales.noarch                 0.34-1.cp1198           installed
cpanel-perl-532-log-any.noarch                 1.708-1.cp1198          installed
cpanel-perl-532-log-any-adapter-callback.noarch
                                               0.101-1.cp1198          installed
cpanel-perl-532-log-any-adapter-log4perl.noarch
                                               0.09-1.cp1198           installed
cpanel-perl-532-log-dispatch.noarch            2.70-1.cp1198           installed
cpanel-perl-532-log-dispatch-array.noarch      1.003-1.cp1198          installed
cpanel-perl-532-log-dispatch-config.noarch     1.04-1.cp1198           installed
cpanel-perl-532-log-dispatchouli.noarch        2.022-1.cp1198          installed
cpanel-perl-532-log-log4perl.noarch            1.53-1.cp1198           installed
cpanel-perl-532-log-log4perl-datadumper.noarch 0.01-1.cp1198           installed
cpanel-perl-532-log-message.noarch             0.08-1.cp1198           installed
cpanel-perl-532-log-message-simple.noarch      0.10-1.cp1198           installed
cpanel-perl-532-log-minimal.noarch             0.19-1.cp1198           installed
cpanel-perl-532-log-trace.noarch               1.070-1.cp1198          installed
cpanel-perl-532-long-jump.noarch               0.000001-1.cp1198       installed
cpanel-perl-532-lwp-mediatypes.noarch          6.04-1.cp1198           installed
cpanel-perl-532-lwp-online.noarch              1.08-1.cp1198           installed
cpanel-perl-532-lwp-protocol-http-socketunixalt.noarch
                                               0.0204-1.cp1198         installed
cpanel-perl-532-lwp-protocol-https.noarch      6.09-1.cp1198           installed
cpanel-perl-532-lwp-protocol-psgi.noarch       0.11-1.cp1198           installed
cpanel-perl-532-lwp-useragent-determined.noarch
                                               1.07-1.cp1198           installed
cpanel-perl-532-lwp-useragent-dns-hosts.noarch 0.14-1.cp1198           installed
cpanel-perl-532-mail-alias-reader.noarch       0.06-1.cp1198           installed
cpanel-perl-532-mail-authenticationresults.noarch
                                               1.20200824.1-1.cp1198   installed
cpanel-perl-532-mail-dkim.noarch               1.20200907-1.cp1198     installed
cpanel-perl-532-mail-imapclient.noarch         3.42-1.cp1198           installed
cpanel-perl-532-mail-pop3client.noarch         2.19-1.cp1198           installed
cpanel-perl-532-mail-pyzor.noarch              0.06-1.cp1198           installed
cpanel-perl-532-mail-sendeasy.noarch           1.2-1.cp1198            installed
cpanel-perl-532-mail-sender.noarch             0.903-1.cp1198          installed
cpanel-perl-532-mail-sender-easy.noarch        0.0.5-1.cp1198          installed
cpanel-perl-532-mail-sendmail.noarch           0.80-1.cp1198           installed
cpanel-perl-532-mail-spamassassin.x86_64       3.004004-8.cp1198       installed
cpanel-perl-532-mail-spf.noarch                2.9.0-3.cp1198          installed
cpanel-perl-532-mail-srs.noarch                0.31-1.cp1198           installed
cpanel-perl-532-mailtools.noarch               2.21-1.cp1198           installed
cpanel-perl-532-math-base-convert.noarch       0.11-1.cp1198           installed
cpanel-perl-532-math-base85.noarch             0.4-1.cp1198            installed
cpanel-perl-532-math-bigint.noarch             1.999818-1.cp1198       installed
cpanel-perl-532-math-bigint-gmp.x86_64         1.6007-1.cp1198         installed
cpanel-perl-532-math-bigint-pari.noarch        1.3006-1.cp1198         installed
cpanel-perl-532-math-combinatorics.noarch      0.09-1.cp1198           installed
cpanel-perl-532-math-fibonacci.noarch          1.5-1.cp1198            installed
cpanel-perl-532-math-fibonacci-phi.noarch      0.02-1.cp1198           installed
cpanel-perl-532-math-gmp.x86_64                2.20-1.cp1198           installed
cpanel-perl-532-math-pari.x86_64               2.030518-1.cp1198       installed
cpanel-perl-532-math-permute-list.noarch       1.007-1.cp1198          installed
cpanel-perl-532-math-prime-util.x86_64         0.73-1.cp1198           installed
cpanel-perl-532-math-prime-util-gmp.x86_64     0.52-1.cp1198           installed
cpanel-perl-532-math-provableprime.noarch      0.045-1.cp1198          installed
cpanel-perl-532-math-random-isaac.noarch       1.004-1.cp1198          installed
cpanel-perl-532-math-random-isaac-xs.x86_64    1.004-1.cp1198          installed
cpanel-perl-532-math-random-secure.noarch      0.080001-1.cp1198       installed
cpanel-perl-532-math-round.noarch              0.07-1.cp1198           installed
cpanel-perl-532-math-subsets-list.noarch       1.008-1.cp1198          installed
cpanel-perl-532-math-utils.noarch              1.14-1.cp1198           installed
cpanel-perl-532-mce.noarch                     1.874-1.cp1198          installed
cpanel-perl-532-mce-shared.noarch              1.873-1.cp1198          installed
cpanel-perl-532-md5.noarch                     2.03-1.cp1198           installed
cpanel-perl-532-memoize-expirelru.noarch       0.56-1.cp1198           installed
cpanel-perl-532-meta-builder.noarch            0.004-1.cp1198          installed
cpanel-perl-532-metacpan-client.noarch         2.028000-1.cp1198       installed
cpanel-perl-532-mime-base32.noarch             1.303-1.cp1198          installed
cpanel-perl-532-mime-charset.noarch            1.012.2-1.cp1198        installed
cpanel-perl-532-mime-lite.noarch               3.031-1.cp1198          installed
cpanel-perl-532-mime-tools.noarch              5.508-1.cp1198          installed
cpanel-perl-532-mime-types.noarch              2.17-1.cp1198           installed
cpanel-perl-532-minion.noarch                  10.14-1.cp1198          installed
cpanel-perl-532-mixin-linewise.noarch          0.108-1.cp1198          installed
cpanel-perl-532-mldbm.noarch                   2.05-1.cp1198           installed
cpanel-perl-532-mock-config.noarch             0.03-1.cp1198           installed
cpanel-perl-532-mock-quick.noarch              1.111-1.cp1198          installed
cpanel-perl-532-modern-perl.noarch             1.20200211-1.cp1198     installed
cpanel-perl-532-module-build.noarch            0.4231-1.cp1198         installed
cpanel-perl-532-module-build-deprecated.noarch 0.4210-1.cp1198         installed
cpanel-perl-532-module-build-tiny.noarch       0.039-1.cp1198          installed
cpanel-perl-532-module-build-xsutil.x86_64     0.19-1.cp1198           installed
cpanel-perl-532-module-corelist.noarch         5.20201020-1.cp1198     installed
cpanel-perl-532-module-cpanfile.noarch         1.1004-1.cp1198         installed
cpanel-perl-532-module-cpants-analyse.noarch   1.01-1.cp1198           installed
cpanel-perl-532-module-extract-version.noarch  1.113-1.cp1198          installed
cpanel-perl-532-module-extractuse.noarch       0.343-1.cp1198          installed
cpanel-perl-532-module-find.noarch             0.15-1.cp1198           installed
cpanel-perl-532-module-implementation.noarch   0.09-1.cp1198           installed
cpanel-perl-532-module-install.noarch          1.19-1.cp1198           installed
cpanel-perl-532-module-path.noarch             0.19-1.cp1198           installed
cpanel-perl-532-module-pluggable.noarch        5.2-1.cp1198            installed
cpanel-perl-532-module-refresh.noarch          0.17-1.cp1198           installed
cpanel-perl-532-module-runtime.noarch          0.016-1.cp1198          installed
cpanel-perl-532-module-runtime-conflicts.noarch
                                               0.003-1.cp1198          installed
cpanel-perl-532-module-scandeps.x86_64         1.29-1.cp1198           installed
cpanel-perl-532-module-signature.noarch        0.87-1.cp1198           installed
cpanel-perl-532-module-util.noarch             1.09-1.cp1198           installed
cpanel-perl-532-module-want.noarch             0.6-1.cp1198            installed
cpanel-perl-532-mojo-jwt.noarch                0.08-1.cp1198           installed
cpanel-perl-532-mojo-pg.noarch                 4.21-1.cp1198           installed
cpanel-perl-532-mojo-server-cgi-legacymigrate.noarch
                                               0.01-1.cp1198           installed
cpanel-perl-532-mojolicious.noarch             8.63-1.cp1198           installed
cpanel-perl-532-mojolicious-plugin-authentication.noarch
                                               1.33-1.cp1198           installed
cpanel-perl-532-mojolicious-plugin-clientip.noarch
                                               0.02-1.cp1198           installed
cpanel-perl-532-mojolicious-plugin-debugdumperhelper.noarch
                                               0.03-1.cp1198           installed
cpanel-perl-532-mojolicious-plugin-oauth2-server.noarch
                                               0.47-1.cp1198           installed
cpanel-perl-532-moment.noarch                  1.3.2-1.cp1198          installed
cpanel-perl-532-moo.noarch                     2.004000-1.cp1198       installed
cpanel-perl-532-moose.x86_64                   2.2013-1.cp1198         installed
cpanel-perl-532-moose-autobox.noarch           0.16-1.cp1198           installed
cpanel-perl-532-moosex-attributehelpers.noarch 0.25-1.cp1198           installed
cpanel-perl-532-moosex-attributeshortcuts.noarch
                                               0.037-1.cp1198          installed
cpanel-perl-532-moosex-classattribute.noarch   0.29-1.cp1198           installed
cpanel-perl-532-moosex-configfromfile.noarch   0.14-1.cp1198           installed
cpanel-perl-532-moosex-configuration.noarch    0.02-1.cp1198           installed
cpanel-perl-532-moosex-daemonize.noarch        0.22-1.cp1198           installed
cpanel-perl-532-moosex-emulate-class-accessor-fast.noarch
                                               0.009032-1.cp1198       installed
cpanel-perl-532-moosex-getopt.noarch           0.74-1.cp1198           installed
cpanel-perl-532-moosex-has-sugar.noarch        1.000006-1.cp1198       installed
cpanel-perl-532-moosex-lazyrequire.noarch      0.11-1.cp1198           installed
cpanel-perl-532-moosex-markasmethods.noarch    0.15-1.cp1198           installed
cpanel-perl-532-moosex-meta-typeconstraint-mooish.noarch
                                               0.001-1.cp1198          installed
cpanel-perl-532-moosex-methodattributes.noarch 0.32-1.cp1198           installed
cpanel-perl-532-moosex-nonmoose.noarch         0.26-1.cp1198           installed
cpanel-perl-532-moosex-object-pluggable.noarch 0.0014-1.cp1198         installed
cpanel-perl-532-moosex-oneargnew.noarch        0.005-1.cp1198          installed
cpanel-perl-532-moosex-params-validate.noarch  0.21-1.cp1198           installed
cpanel-perl-532-moosex-poe.noarch              0.215-1.cp1198          installed
cpanel-perl-532-moosex-relatedclassroles.noarch
                                               0.004-1.cp1198          installed
cpanel-perl-532-moosex-role-parameterized.noarch
                                               1.11-1.cp1198           installed
cpanel-perl-532-moosex-role-withoverloading.x86_64
                                               0.17-1.cp1198           installed
cpanel-perl-532-moosex-semiaffordanceaccessor.noarch
                                               0.10-1.cp1198           installed
cpanel-perl-532-moosex-setonce.noarch          0.200002-1.cp1198       installed
cpanel-perl-532-moosex-simpleconfig.noarch     0.11-1.cp1198           installed
cpanel-perl-532-moosex-singleton.noarch        0.30-1.cp1198           installed
cpanel-perl-532-moosex-slurpyconstructor.noarch
                                               1.30-1.cp1198           installed
cpanel-perl-532-moosex-traitfor-meta-class-betteranonclassnames.noarch
                                               0.002003-1.cp1198       installed
cpanel-perl-532-moosex-traits-pluggable.noarch 0.12-1.cp1198           installed
cpanel-perl-532-moosex-types.noarch            0.50-1.cp1198           installed
cpanel-perl-532-moosex-types-common.noarch     0.001014-1.cp1198       installed
cpanel-perl-532-moosex-types-datetime.noarch   0.13-1.cp1198           installed
cpanel-perl-532-moosex-types-loadableclass.noarch
                                               0.015-1.cp1198          installed
cpanel-perl-532-moosex-types-path-class.noarch 0.09-1.cp1198           installed
cpanel-perl-532-moosex-types-path-tiny.noarch  0.012-1.cp1198          installed
cpanel-perl-532-moosex-types-perl.noarch       0.101343-1.cp1198       installed
cpanel-perl-532-moosex-types-stringlike.noarch 0.003-1.cp1198          installed
cpanel-perl-532-moosex-types-uri.noarch        0.08-1.cp1198           installed
cpanel-perl-532-moosex-util.noarch             0.006-1.cp1198          installed
cpanel-perl-532-moox-classattribute.noarch     0.011-1.cp1198          installed
cpanel-perl-532-moox-handlesvia.noarch         0.001009-1.cp1198       installed
cpanel-perl-532-moox-late.noarch               0.100-1.cp1198          installed
cpanel-perl-532-moox-locale-passthrough.noarch 0.001-1.cp1198          installed
cpanel-perl-532-moox-log-any.noarch            0.004004-1.cp1198       installed
cpanel-perl-532-moox-options.noarch            4.103-1.cp1198          installed
cpanel-perl-532-moox-strictconstructor.noarch  0.011-1.cp1198          installed
cpanel-perl-532-moox-types-mooselike.noarch    0.29-1.cp1198           installed
cpanel-perl-532-moox-types-mooselike-numeric.noarch
                                               1.03-1.cp1198           installed
cpanel-perl-532-mouse.x86_64                   2.5.10-1.cp1198         installed
cpanel-perl-532-mousex-types.noarch            0.06-1.cp1198           installed
cpanel-perl-532-mozilla-ca.noarch              20200520-1.cp1198       installed
cpanel-perl-532-mozilla-publicsuffix.noarch    1.0.0-1.cp1198          installed
cpanel-perl-532-mro-compat.noarch              0.13-1.cp1198           installed
cpanel-perl-532-multidimensional.x86_64        0.014-1.cp1198          installed
cpanel-perl-532-mysql-diff.noarch              0.60-1.cp1198           installed
cpanel-perl-532-namespace-autoclean.noarch     0.29-1.cp1198           installed
cpanel-perl-532-namespace-clean.noarch         0.27-1.cp1198           installed
cpanel-perl-532-net-acme2.noarch               0.35-1.cp1198           installed
cpanel-perl-532-net-address-ipv4-local.noarch  0.12-1.cp1198           installed
cpanel-perl-532-net-aim.noarch                 1.22-1.cp1198           installed
cpanel-perl-532-net-amazon-signature-v3.noarch 0.003-1.cp1198          installed
cpanel-perl-532-net-amazon-signature-v4.noarch 0.21-1.cp1198           installed
cpanel-perl-532-net-amqp.noarch                0.06-1.cp1198           installed
cpanel-perl-532-net-apns-persistent.noarch     0.02-1.cp1198           installed
cpanel-perl-532-net-cidr.noarch                0.20-1.cp1198           installed
cpanel-perl-532-net-cidr-lite.noarch           0.21-1.cp1198           installed
cpanel-perl-532-net-curl.x86_64                0.49-1.cp1198           installed
cpanel-perl-532-net-curl-promiser.noarch       0.17-1.cp1198           installed
cpanel-perl-532-net-daemon.noarch              0.49-1.cp1198           installed
cpanel-perl-532-net-daemon-ssl.noarch          1.0-1.cp1198            installed
cpanel-perl-532-net-dav-server.noarch          1.305-1.cp1198          installed
cpanel-perl-532-net-detect.noarch              0.3-1.cp1198            installed
cpanel-perl-532-net-dns.noarch                 1.28-3.cp1198           installed
cpanel-perl-532-net-dns-resolver-mock.noarch   1.20200215-1.cp1198     installed
cpanel-perl-532-net-dns-resolver-programmable.noarch
                                               0.009-1.cp1198          installed
cpanel-perl-532-net-dns-sec.x86_64             1.18-1.cp1198           installed
cpanel-perl-532-net-domain-tld.noarch          1.75-1.cp1198           installed
cpanel-perl-532-net-fastcgi.noarch             0.14-1.cp1198           installed
cpanel-perl-532-net-ftpssl.noarch              0.42-1.cp1198           installed
cpanel-perl-532-net-github.noarch              1.01-1.cp1198           installed
cpanel-perl-532-net-google-drive-simple.noarch 0.19-1.cp1198           installed
cpanel-perl-532-net-http.noarch                6.19-1.cp1198           installed
cpanel-perl-532-net-https-any.noarch           0.12-1.cp1198           installed
cpanel-perl-532-net-httptunnel.noarch          0.51-1.cp1198           installed
cpanel-perl-532-net-ident.noarch               1.25-1.cp1198           installed
cpanel-perl-532-net-idn-encode.x86_64          2.500-1.cp1198          installed
cpanel-perl-532-net-imap-client.noarch         0.9505-1.cp1198         installed
cpanel-perl-532-net-imap-simple.noarch         1.2212-1.cp1198         installed
cpanel-perl-532-net-ip.noarch                  1.26-1.cp1198           installed
cpanel-perl-532-net-ip-match-regexp.noarch     1.01-1.cp1198           installed
cpanel-perl-532-net-ipv4addr.noarch            0.10-1.cp1198           installed
cpanel-perl-532-net-jabber.noarch              2.0-1.cp1198            installed
cpanel-perl-532-net-jabber-bot.noarch          2.1.6-1.cp1198          installed
cpanel-perl-532-net-ldap-server.noarch         0.43-1.cp1198           installed
cpanel-perl-532-net-libidn.x86_64              0.12-1.cp1198           installed
cpanel-perl-532-net-mysql.noarch               0.11-1.cp1198           installed
cpanel-perl-532-net-netmask.noarch             1.9104-1.cp1198         installed
cpanel-perl-532-net-oauth.noarch               0.28-1.cp1198           installed
cpanel-perl-532-net-oauth2-authorizationserver.noarch
                                               0.28-1.cp1198           installed
cpanel-perl-532-net-openssh.noarch             0.80-1.cp1198           installed
cpanel-perl-532-net-oscar.noarch               1.928-1.cp1198          installed
cpanel-perl-532-net-rabbitmq.x86_64            0.2.8-1.cp1198          installed
cpanel-perl-532-net-rndc.noarch                0.003-1.cp1198          installed
cpanel-perl-532-net-server.noarch              2.009-1.cp1198          installed
cpanel-perl-532-net-sftp-foreign.noarch        1.91-1.cp1198           installed
cpanel-perl-532-net-snmp.noarch                6.0.1-1.cp1198          installed
cpanel-perl-532-net-socks.noarch               0.03-1.cp1198           installed
cpanel-perl-532-net-ssh-perl.x86_64            2.14-1.cp1198           installed
cpanel-perl-532-net-ssleay.x86_64              1.90-1.cp1198           installed
cpanel-perl-532-net-stomp-client.noarch        2.3-1.cp1198            installed
cpanel-perl-532-net-telnet.noarch              3.04-1.cp1198           installed
cpanel-perl-532-net-twitter-lite.noarch        0.12008-1.cp1198        installed
cpanel-perl-532-net-websocket.noarch           0.22-1.cp1198           installed
cpanel-perl-532-net-whois-iana.noarch          0.46-1.cp1198           installed
cpanel-perl-532-net-xmpp.noarch                1.05-1.cp1198           installed
cpanel-perl-532-netaddr-ip.x86_64              4.079-1.cp1198          installed
cpanel-perl-532-netpacket.noarch               1.7.2-1.cp1198          installed
cpanel-perl-532-no-worries.noarch              1.6-1.cp1198            installed
cpanel-perl-532-number-compare.noarch          0.03-1.cp1198           installed
cpanel-perl-532-number-tolerant.noarch         1.708-1.cp1198          installed
cpanel-perl-532-number-witherror.noarch        1.01-1.cp1198           installed
cpanel-perl-532-oauth-cmdline.noarch           0.06-1.cp1198           installed
cpanel-perl-532-oauth-lite2.noarch             0.11-1.cp1198           installed
cpanel-perl-532-object-accessor.noarch         0.48-1.cp1198           installed
cpanel-perl-532-object-event.noarch            1.23-1.cp1198           installed
cpanel-perl-532-object-signature.noarch        1.08-1.cp1198           installed
cpanel-perl-532-oidc-lite.noarch               0.10-1.cp1198           installed
cpanel-perl-532-ole-storage.lite.noarch        0.20-1.cp1198           installed
cpanel-perl-532-opcodes.x86_64                 0.14-1.cp1198           installed
cpanel-perl-532-opendns-myip.noarch            1.152350-1.cp1198       installed
cpanel-perl-532-openstack-client.noarch        1.0007-1.cp1198         installed
cpanel-perl-532-openstack-metaapi.noarch       0.003-1.cp1198          installed
cpanel-perl-532-ouroboros.x86_64               0.14-1.cp1198           installed
cpanel-perl-532-overload-filecheck.x86_64      0.012-1.cp1198          installed
cpanel-perl-532-package-constants.noarch       0.06-1.cp1198           installed
cpanel-perl-532-package-deprecationmanager.noarch
                                               0.17-1.cp1198           installed
cpanel-perl-532-package-stash.noarch           0.38-1.cp1198           installed
cpanel-perl-532-package-stash-xs.x86_64        0.29-1.cp1198           installed
cpanel-perl-532-package-variant.noarch         1.003002-1.cp1198       installed
cpanel-perl-532-padwalker.x86_64               2.5-1.cp1198            installed
cpanel-perl-532-par-dist.noarch                0.49-1.cp1198           installed
cpanel-perl-532-parallel-forkmanager.noarch    2.02-1.cp1198           installed
cpanel-perl-532-parallel-prefork.noarch        0.18-1.cp1198           installed
cpanel-perl-532-parallel-scoreboard.noarch     0.08-1.cp1198           installed
cpanel-perl-532-parallel-subs.noarch           0.002-1.cp1198          installed
cpanel-perl-532-params-util.x86_64             1.102-1.cp1198          installed
cpanel-perl-532-params-validate.x86_64         1.30-1.cp1198           installed
cpanel-perl-532-params-validationcompiler.noarch
                                               0.30-1.cp1198           installed
cpanel-perl-532-parse-cpan-packages-fast.noarch
                                               0.09-1.cp1198           installed
cpanel-perl-532-parse-localdistribution.noarch 0.19-1.cp1198           installed
cpanel-perl-532-parse-mime.noarch              1.005-1.cp1198          installed
cpanel-perl-532-parse-pmfile.noarch            0.42-1.cp1198           installed
cpanel-perl-532-parse-recdescent.x86_64        1.967015-1.cp1198       installed
cpanel-perl-532-parse-yapp.noarch              1.21-1.cp1198           installed
cpanel-perl-532-path-class.noarch              0.37-1.cp1198           installed
cpanel-perl-532-path-finddev.noarch            0.5.3-1.cp1198          installed
cpanel-perl-532-path-isdev.noarch              1.001003-1.cp1198       installed
cpanel-perl-532-path-iter.noarch               0.2-1.cp1198            installed
cpanel-perl-532-path-iterator-rule.noarch      1.014-1.cp1198          installed
cpanel-perl-532-path-tiny.noarch               0.114-1.cp1198          installed
cpanel-perl-532-pause-permissions.noarch       0.17-1.cp1198           installed
cpanel-perl-532-pdf-api2.noarch                2.038-1.cp1198          installed
cpanel-perl-532-perl-critic.noarch             1.138-1.cp1198          installed
cpanel-perl-532-perl-critic-community.noarch   1.0.2-2.cp1198          installed
cpanel-perl-532-perl-critic-cpanel.noarch      0.10-1.cp1198           installed
cpanel-perl-532-perl-critic-policy-compiletime.noarch
                                               0.03-1.cp1198           installed
cpanel-perl-532-perl-critic-policy-variables-prohibitlooponhash.noarch
                                               0.008-1.cp1198          installed
cpanel-perl-532-perl-critic-pulp.x86_64        99-1.cp1198             installed
cpanel-perl-532-perl-critic-strictersubs.noarch
                                               0.05-1.cp1198           installed
cpanel-perl-532-perl-languageserver.noarch     2.1.0-1.cp1198          installed
cpanel-perl-532-perl-ldap.noarch               0.66-1.cp1198           installed
cpanel-perl-532-perl-minimumversion.noarch     1.38-1.cp1198           installed
cpanel-perl-532-perl-osnames.noarch            0.122-1.cp1198          installed
cpanel-perl-532-perl-phase.x86_64              0.03-1.cp1198           installed
cpanel-perl-532-perl-prereqscanner.noarch      1.023-1.cp1198          installed
cpanel-perl-532-perl-prereqscanner-notquitelite.noarch
                                               0.9913-1.cp1198         installed
cpanel-perl-532-perl-strip.noarch              1.1-1.cp1198            installed
cpanel-perl-532-perl-tidy.noarch               20201001-1.cp1198       installed
cpanel-perl-532-perl-version.noarch            1.013-1.cp1198          installed
cpanel-perl-532-perl6-junction.noarch          1.60000-1.cp1198        installed
cpanel-perl-532-perlbal.noarch                 1.80-1.cp1198           installed
cpanel-perl-532-perlio-utf8.strict.x86_64      0.008-1.cp1198          installed
cpanel-perl-532-perlio-via-timeout.noarch      0.32-1.cp1198           installed
cpanel-perl-532-php-serialization.noarch       0.34-1.cp1198           installed
cpanel-perl-532-plack.noarch                   1.0047-1.cp1198         installed
cpanel-perl-532-plack-app-vhost.noarch         0.01-1.cp1198           installed
cpanel-perl-532-plack-middleware-fixmissingbodyinredirect.noarch
                                               0.12-1.cp1198           installed
cpanel-perl-532-plack-middleware-forceenv.noarch
                                               0.02-1.cp1198           installed
cpanel-perl-532-plack-middleware-header.noarch 0.04-1.cp1198           installed
cpanel-perl-532-plack-middleware-logerrors.noarch
                                               0.003-1.cp1198          installed
cpanel-perl-532-plack-middleware-methodoverride.noarch
                                               0.20-1.cp1198           installed
cpanel-perl-532-plack-middleware-removeredundantbody.noarch
                                               0.09-1.cp1198           installed
cpanel-perl-532-plack-middleware-reverseproxy.noarch
                                               0.16-1.cp1198           installed
cpanel-perl-532-plack-middleware-reviseenv.noarch
                                               0.004-1.cp1198          installed
cpanel-perl-532-plack-middleware-session.noarch
                                               0.33-1.cp1198           installed
cpanel-perl-532-plack-middleware-xforwardedfor.noarch
                                               0.172050-1.cp1198       installed
cpanel-perl-532-plack-test-externalserver.noarch
                                               0.02-1.cp1198           installed
cpanel-perl-532-pod-coverage.noarch            0.23-1.cp1198           installed
cpanel-perl-532-pod-coverage-trustpod.noarch   0.100005-1.cp1198       installed
cpanel-perl-532-pod-elemental.noarch           0.103005-1.cp1198       installed
cpanel-perl-532-pod-elemental-makeselector.noarch
                                               0.12-1.cp1198           installed
cpanel-perl-532-pod-elemental-perlmunger.noarch
                                               0.200006-1.cp1198       installed
cpanel-perl-532-pod-elemental-transformer-list.noarch
                                               0.102000-1.cp1198       installed
cpanel-perl-532-pod-elemental-transformer-verbatim.noarch
                                               0.001-1.cp1198          installed
cpanel-perl-532-pod-eventual.noarch            0.094001-1.cp1198       installed
cpanel-perl-532-pod-latex.noarch               0.61-1.cp1198           installed
cpanel-perl-532-pod-markdown.noarch            3.300-1.cp1198          installed
cpanel-perl-532-pod-markdown-github.noarch     0.04-1.cp1198           installed
cpanel-perl-532-pod-minimumversion.noarch      50-1.cp1198             installed
cpanel-perl-532-pod-parser.noarch              1.63-1.cp1198           installed
cpanel-perl-532-pod-readme.noarch              1.2.3-1.cp1198          installed
cpanel-perl-532-pod-spell.noarch               1.20-1.cp1198           installed
cpanel-perl-532-pod-strip.noarch               1.02-1.cp1198           installed
cpanel-perl-532-pod-weaver.noarch              4.015-1.cp1198          installed
cpanel-perl-532-pod-weaver-section-allowoverride.noarch
                                               0.05-1.cp1198           installed
cpanel-perl-532-pod-weaver-section-contributors.noarch
                                               0.009-1.cp1198          installed
cpanel-perl-532-pod-weaver-section-generatesection.noarch
                                               1.06-1.cp1198           installed
cpanel-perl-532-poe.noarch                     1.368-1.cp1198          installed
cpanel-perl-532-poe-test-loops.noarch          1.360-1.cp1198          installed
cpanel-perl-532-posix-1003.x86_64              1.02-1.cp1198           installed
cpanel-perl-532-posix-strftime-compiler.noarch 0.44-1.cp1198           installed
cpanel-perl-532-ppi.noarch                     1.270-1.cp1198          installed
cpanel-perl-532-ppix-quotelike.noarch          0.013-1.cp1198          installed
cpanel-perl-532-ppix-regexp.noarch             0.075-1.cp1198          installed
cpanel-perl-532-ppix-utilities.noarch          1.001000-1.cp1198       installed
cpanel-perl-532-prefork.noarch                 1.05-1.cp1198           installed
cpanel-perl-532-pristine-tar.x86_64            1.40-3.cp1198           installed
cpanel-perl-532-probe-perl.noarch              0.03-1.cp1198           installed
cpanel-perl-532-proc-daemon.noarch             0.23-1.cp1198           installed
cpanel-perl-532-proc-fastspawn.x86_64          1.2-1.cp1198            installed
cpanel-perl-532-proc-guard.noarch              0.07-1.cp1198           installed
cpanel-perl-532-proc-pid-file.noarch           1.29-1.cp1198           installed
cpanel-perl-532-proc-processtable.x86_64       0.59-1.cp1198           installed
cpanel-perl-532-proc-wait3.x86_64              0.05-1.cp1198           installed
cpanel-perl-532-promise-es6.noarch             0.23-1.cp1198           installed
cpanel-perl-532-promise-xs.x86_64              0.11-2.cp1198           installed
cpanel-perl-532-protocol-dbus.noarch           0.16-1.cp1198           installed
cpanel-perl-532-protocol-websocket.noarch      0.26-1.cp1198           installed
cpanel-perl-532-quota.x86_64                   1.8.2-2.cp1198          installed
cpanel-perl-532-razor2-client-agent.x86_64     2.86-2.cp1198           installed
cpanel-perl-532-readonly.noarch                2.05-1.cp1198           installed
cpanel-perl-532-readonly-xs.x86_64             1.05-1.cp1198           installed
cpanel-perl-532-reddit-client.noarch           1.38-1.cp1198           installed
cpanel-perl-532-redis.noarch                   1.998-1.cp1198          installed
cpanel-perl-532-ref-util.noarch                0.204-1.cp1198          installed
cpanel-perl-532-ref-util-rewriter.noarch       0.100-1.cp1198          installed
cpanel-perl-532-ref-util-xs.x86_64             0.117-1.cp1198          installed
cpanel-perl-532-regexp-assemble.noarch         0.38-1.cp1198           installed
cpanel-perl-532-regexp-common.noarch           2017060201-1.cp1198     installed
cpanel-perl-532-regexp-debugger.noarch         0.002006-1.cp1198       installed
cpanel-perl-532-regexp-parser.noarch           0.23-1.cp1198           installed
cpanel-perl-532-regexp-trie.noarch             0.02-1.cp1198           installed
cpanel-perl-532-rest-client.noarch             273-1.cp1198            installed
cpanel-perl-532-rest-google.noarch             1.0.8-1.cp1198          installed
cpanel-perl-532-return-multilevel.noarch       0.05-1.cp1198           installed
cpanel-perl-532-return-value.noarch            1.666005-1.cp1198       installed
cpanel-perl-532-rivescript.noarch              2.0.3-1.cp1198          installed
cpanel-perl-532-role-hasmessage.noarch         0.006-1.cp1198          installed
cpanel-perl-532-role-identifiable.noarch       0.007-1.cp1198          installed
cpanel-perl-532-role-multiton.noarch           0.2-1.cp1198            installed
cpanel-perl-532-role-rest-client.noarch        0.23-1.cp1198           installed
cpanel-perl-532-role-tiny.noarch               2.001004-1.cp1198       installed
cpanel-perl-532-router-simple.noarch           0.17-1.cp1198           installed
cpanel-perl-532-rt-client-rest.noarch          0.60-1.cp1198           installed
cpanel-perl-532-safe-hole.x86_64               0.14-1.cp1198           installed
cpanel-perl-532-safe-isa.noarch                1.000010-1.cp1198       installed
cpanel-perl-532-scalar-util-numeric.x86_64     0.40-1.cp1198           installed
cpanel-perl-532-schedule-cron-events.noarch    1.96-1.cp1198           installed
cpanel-perl-532-scope-guard.noarch             0.21-1.cp1198           installed
cpanel-perl-532-scope-upper.x86_64             0.32-1.cp1198           installed
cpanel-perl-532-search-elasticsearch.noarch    7.30-1.cp1198           installed
cpanel-perl-532-selenium-pageobject.noarch     0.012-1.cp1198          installed
cpanel-perl-532-selenium-remote-driver.noarch  1.38-1.cp1198           installed
cpanel-perl-532-sereal.noarch                  4.018-1.cp1198          installed
cpanel-perl-532-sereal-decoder.x86_64          4.018-1.cp1198          installed
cpanel-perl-532-sereal-encoder.x86_64          4.018-1.cp1198          installed
cpanel-perl-532-server-starter.noarch          0.35-1.cp1198           installed
cpanel-perl-532-session-storage-secure.noarch  0.011-1.cp1198          installed
cpanel-perl-532-session-token.x86_64           1.503-1.cp1198          installed
cpanel-perl-532-set-crontab.noarch             1.03-1.cp1198           installed
cpanel-perl-532-set-object.x86_64              1.40-1.cp1198           installed
cpanel-perl-532-set-scalar.noarch              1.29-1.cp1198           installed
cpanel-perl-532-shell.noarch                   0.73-1.cp1198           installed
cpanel-perl-532-signal-mask.noarch             0.008-1.cp1198          installed
cpanel-perl-532-simple-accessor.noarch         1.13-1.cp1198           installed
cpanel-perl-532-slack-webhook.noarch           0.003-1.cp1198          installed
cpanel-perl-532-smart-comments.noarch          1.06-1.cp1198           installed
cpanel-perl-532-snowball-norwegian.noarch      1.2-1.cp1198            installed
cpanel-perl-532-snowball-swedish.noarch        1.2-1.cp1198            installed
cpanel-perl-532-soap-lite.noarch               1.27-1.cp1198           installed
cpanel-perl-532-socket6.x86_64                 0.29-1.cp1198           installed
cpanel-perl-532-software-license.noarch        0.103014-1.cp1198       installed
cpanel-perl-532-software-license-ccpack.noarch 1.11-1.cp1198           installed
cpanel-perl-532-sort-naturally.noarch          1.03-1.cp1198           installed
cpanel-perl-532-sort-versions.noarch           1.62-1.cp1198           installed
cpanel-perl-532-specio.noarch                  0.46-1.cp1198           installed
cpanel-perl-532-sphinx-search.noarch           0.31-1.cp1198           installed
cpanel-perl-532-spiffy.noarch                  0.46-1.cp1198           installed
cpanel-perl-532-spreadsheet-parseexcel.noarch  0.65-1.cp1198           installed
cpanel-perl-532-spreadsheet-read.noarch        0.82-1.cp1198           installed
cpanel-perl-532-spreadsheet-writeexcel.noarch  2.40-1.cp1198           installed
cpanel-perl-532-sql-abstract.noarch            1.87-1.cp1198           installed
cpanel-perl-532-sql-abstract-classic.noarch    1.91-1.cp1198           installed
cpanel-perl-532-sql-maker.noarch               1.21-1.cp1198           installed
cpanel-perl-532-sql-querymaker.noarch          0.03-1.cp1198           installed
cpanel-perl-532-sql-statement.noarch           1.414-1.cp1198          installed
cpanel-perl-532-sql-translator.noarch          1.62-1.cp1198           installed
cpanel-perl-532-starlet.noarch                 0.31-1.cp1198           installed
cpanel-perl-532-starman.noarch                 0.4015-1.cp1198         installed
cpanel-perl-532-statistics-caseresampling.x86_64
                                               0.15-1.cp1198           installed
cpanel-perl-532-statistics-chisquare.noarch    1.0000-1.cp1198         installed
cpanel-perl-532-statistics-descriptive.noarch  3.0800-1.cp1198         installed
cpanel-perl-532-statistics-linefit.noarch      0.07-1.cp1198           installed
cpanel-perl-532-stf-dispatcher-psgi.noarch     1.12-1.cp1198           installed
cpanel-perl-532-stream-buffered.noarch         0.03-1.cp1198           installed
cpanel-perl-532-strictures.noarch              2.000006-1.cp1198       installed
cpanel-perl-532-string-base.x86_64             0.003-1.cp1198          installed
cpanel-perl-532-string-bom.noarch              0.3-1.cp1198            installed
cpanel-perl-532-string-camelcase.noarch        0.04-1.cp1198           installed
cpanel-perl-532-string-compare-constanttime.x86_64
                                               0.321-1.cp1198          installed
cpanel-perl-532-string-crc32.x86_64            1.8-1.cp1198            installed
cpanel-perl-532-string-errf.noarch             0.008-1.cp1198          installed
cpanel-perl-532-string-flogger.noarch          1.101245-1.cp1198       installed
cpanel-perl-532-string-format.noarch           1.18-1.cp1198           installed
cpanel-perl-532-string-formatter.noarch        0.102084-1.cp1198       installed
cpanel-perl-532-string-perlquote.noarch        0.02-1.cp1198           installed
cpanel-perl-532-string-random.noarch           0.31-1.cp1198           installed
cpanel-perl-532-string-rewriteprefix.noarch    0.008-1.cp1198          installed
cpanel-perl-532-string-shellquote.noarch       1.04-1.cp1198           installed
cpanel-perl-532-string-toidentifier-en.noarch  0.12-1.cp1198           installed
cpanel-perl-532-string-truncate.noarch         1.100602-1.cp1198       installed
cpanel-perl-532-string-unicodeutf8.noarch      0.23-1.cp1198           installed
cpanel-perl-532-string-unquotemeta.noarch      0.1-1.cp1198            installed
cpanel-perl-532-string-urandom.noarch          0.16-1.cp1198           installed
cpanel-perl-532-sub-attribute.x86_64           0.07-1.cp1198           installed
cpanel-perl-532-sub-delete.noarch              1.00002-1.cp1198        installed
cpanel-perl-532-sub-exporter.noarch            0.987-1.cp1198          installed
cpanel-perl-532-sub-exporter-formethods.noarch 0.100052-1.cp1198       installed
cpanel-perl-532-sub-exporter-globexporter.noarch
                                               0.005-1.cp1198          installed
cpanel-perl-532-sub-exporter-progressive.noarch
                                               0.001013-1.cp1198       installed
cpanel-perl-532-sub-handlesvia.noarch          0.016-1.cp1198          installed
cpanel-perl-532-sub-identify.x86_64            0.14-1.cp1198           installed
cpanel-perl-532-sub-info.noarch                0.002-1.cp1198          installed
cpanel-perl-532-sub-install.noarch             0.928-1.cp1198          installed
cpanel-perl-532-sub-name.x86_64                0.26-1.cp1198           installed
cpanel-perl-532-sub-quote.noarch               2.006006-1.cp1198       installed
cpanel-perl-532-sub-uplevel.noarch             0.2800-1.cp1198         installed
cpanel-perl-532-super.noarch                   1.20190531-1.cp1198     installed
cpanel-perl-532-superclass.noarch              0.003-1.cp1198          installed
cpanel-perl-532-svg.noarch                     2.85-1.cp1198           installed
cpanel-perl-532-svg-parser.noarch              1.03-1.cp1198           installed
cpanel-perl-532-svg-spritemaker.noarch         0.002-1.cp1198          installed
cpanel-perl-532-svg-tt-graph.noarch            1.04-1.cp1198           installed
cpanel-perl-532-svggraph.noarch                0.07-1.cp1198           installed
cpanel-perl-532-switch.noarch                  2.17-1.cp1198           installed
cpanel-perl-532-symbol-get.noarch              0.10-1.cp1198           installed
cpanel-perl-532-symbol-util.noarch             0.0203-1.cp1198         installed
cpanel-perl-532-syntax.noarch                  0.004-1.cp1198          installed
cpanel-perl-532-syntax-keyword-junction.noarch 0.003008-1.cp1198       installed
cpanel-perl-532-sys-hostname-long.noarch       1.5-1.cp1198            installed
cpanel-perl-532-sys-info.noarch                0.7811-1.cp1198         installed
cpanel-perl-532-sys-info-base.noarch           0.7807-1.cp1198         installed
cpanel-perl-532-sys-info-driver-linux.noarch   0.7905-1.cp1198         installed
cpanel-perl-532-sys-mmap.x86_64                0.20-1.cp1198           installed
cpanel-perl-532-sys-sigaction.noarch           0.23-1.cp1198           installed
cpanel-perl-532-sys-statistics-linux.noarch    0.66-1.cp1198           installed
cpanel-perl-532-sys-syscall.noarch             0.25-1.cp1198           installed
cpanel-perl-532-sys-trace.noarch               0.03-1.cp1198           installed
cpanel-perl-532-sysadm-install.noarch          0.48-1.cp1198           installed
cpanel-perl-532-system-command.noarch          1.121-1.cp1198          installed
cpanel-perl-532-system-info.noarch             0.059-1.cp1198          installed
cpanel-perl-532-tap-formatter-bamboo.noarch    0.04-1.cp1198           installed
cpanel-perl-532-tap-formatter-junit.noarch     0.11-1.cp1198           installed
cpanel-perl-532-tap-harness-junit.noarch       0.42-1.cp1198           installed
cpanel-perl-532-tap-simpleoutput.noarch        0.009-1.cp1198          installed
cpanel-perl-532-task-weaken.noarch             1.06-1.cp1198           installed
cpanel-perl-532-template-plugin-comma.noarch   0.04-1.cp1198           installed
cpanel-perl-532-template-plugin-javascript.noarch
                                               0.02-1.cp1198           installed
cpanel-perl-532-template-timer.noarch          1.00-1.cp1198           installed
cpanel-perl-532-template-tiny.noarch           1.12-1.cp1198           installed
cpanel-perl-532-template-toolkit.x86_64        3.010-1.cp1198          installed
cpanel-perl-532-term-encoding.noarch           0.03-1.cp1198           installed
cpanel-perl-532-term-progressbar.noarch        2.22-1.cp1198           installed
cpanel-perl-532-term-readline-gnu.x86_64       1.36-1.cp1198           installed
cpanel-perl-532-term-table.noarch              0.015-1.cp1198          installed
cpanel-perl-532-term-ui.noarch                 0.46-1.cp1198           installed
cpanel-perl-532-termreadkey.x86_64             2.38-1.cp1198           installed
cpanel-perl-532-test-allmodules.noarch         0.17-1.cp1198           installed
cpanel-perl-532-test-api.noarch                0.010-1.cp1198          installed
cpanel-perl-532-test-assertions.noarch         1.054-1.cp1198          installed
cpanel-perl-532-test-base.noarch               0.89-1.cp1198           installed
cpanel-perl-532-test-carp.noarch               0.2-1.cp1198            installed
cpanel-perl-532-test-checkdeps.noarch          0.010-1.cp1198          installed
cpanel-perl-532-test-checkmanifest.noarch      1.42-1.cp1198           installed
cpanel-perl-532-test-class.noarch              0.50-1.cp1198           installed
cpanel-perl-532-test-class-moose.noarch        0.98-1.cp1198           installed
cpanel-perl-532-test-class-tiny.noarch         0.03-1.cp1198           installed
cpanel-perl-532-test-classapi.noarch           1.07-1.cp1198           installed
cpanel-perl-532-test-cleannamespaces.noarch    0.24-1.cp1198           installed
cpanel-perl-532-test-cmd.noarch                1.09-1.cp1198           installed
cpanel-perl-532-test-cpan-meta.noarch          0.25-1.cp1198           installed
cpanel-perl-532-test-cpan-meta-yaml.noarch     0.25-1.cp1198           installed
cpanel-perl-532-test-deep.noarch               1.130-1.cp1198          installed
cpanel-perl-532-test-deep-json.noarch          0.05-1.cp1198           installed
cpanel-perl-532-test-describeme.noarch         0.004-1.cp1198          installed
cpanel-perl-532-test-detect.noarch             0.1-1.cp1198            installed
cpanel-perl-532-test-differences.noarch        0.67-1.cp1198           installed
cpanel-perl-532-test-eol.noarch                2.00-1.cp1198           installed
cpanel-perl-532-test-exception.noarch          0.43-1.cp1198           installed
cpanel-perl-532-test-exit.noarch               0.11-1.cp1198           installed
cpanel-perl-532-test-expect.noarch             0.34-1.cp1198           installed
cpanel-perl-532-test-failwarnings.noarch       0.008-1.cp1198          installed
cpanel-perl-532-test-fake-httpd.noarch         0.09-1.cp1198           installed
cpanel-perl-532-test-fatal.noarch              0.016-1.cp1198          installed
cpanel-perl-532-test-file.noarch               1.443-1.cp1198          installed
cpanel-perl-532-test-file-contents.noarch      0.23-1.cp1198           installed
cpanel-perl-532-test-file-sharedir.noarch      1.001002-1.cp1198       installed
cpanel-perl-532-test-filename.noarch           0.03-1.cp1198           installed
cpanel-perl-532-test-fork.noarch               0.02-1.cp1198           installed
cpanel-perl-532-test-hexstring.noarch          0.03-1.cp1198           installed
cpanel-perl-532-test-inter.noarch              1.09-1.cp1198           installed
cpanel-perl-532-test-kit.noarch                2.15-1.cp1198           installed
cpanel-perl-532-test-kwalitee.noarch           1.28-1.cp1198           installed
cpanel-perl-532-test-leaktrace.x86_64          0.16-1.cp1198           installed
cpanel-perl-532-test-lectrotest.noarch         0.5001-1.cp1198         installed
cpanel-perl-532-test-lib.noarch                0.002-1.cp1198          installed
cpanel-perl-532-test-longstring.noarch         0.17-1.cp1198           installed
cpanel-perl-532-test-lwp-useragent.noarch      0.034-1.cp1198          installed
cpanel-perl-532-test-manifest.noarch           2.021-1.cp1198          installed
cpanel-perl-532-test-memory-cycle.noarch       1.06-1.cp1198           installed
cpanel-perl-532-test-minimumversion.noarch     0.101082-1.cp1198       installed
cpanel-perl-532-test-mock-cmd.noarch           0.7-1.cp1198            installed
cpanel-perl-532-test-mock-furl.noarch          0.05-1.cp1198           installed
cpanel-perl-532-test-mock-guard.noarch         0.10-1.cp1198           installed
cpanel-perl-532-test-mock-lwp.noarch           0.08-1.cp1198           installed
cpanel-perl-532-test-mock-lwp-conditional.noarch
                                               0.04-1.cp1198           installed
cpanel-perl-532-test-mockdatetime.noarch       0.02-1.cp1198           installed
cpanel-perl-532-test-mockfile.noarch           0.024-1.cp1198          installed
cpanel-perl-532-test-mockmodule.noarch         0.175.0-1.cp1198        installed
cpanel-perl-532-test-mockobject.noarch         1.20200122-1.cp1198     installed
cpanel-perl-532-test-mocktime.noarch           0.17-1.cp1198           installed
cpanel-perl-532-test-modern.noarch             0.013-1.cp1198          installed
cpanel-perl-532-test-mojibake.noarch           1.3-1.cp1198            installed
cpanel-perl-532-test-mojo-role-debug.noarch    1.004001-1.cp1198       installed
cpanel-perl-532-test-mojo-role-debug-json.noarch
                                               0.005-1.cp1198          installed
cpanel-perl-532-test-mojo-role-testdeep.noarch 0.007-1.cp1198          installed
cpanel-perl-532-test-mojo-withroles.noarch     0.02-1.cp1198           installed
cpanel-perl-532-test-moose-more.noarch         0.050-1.cp1198          installed
cpanel-perl-532-test-more-utf8.noarch          0.05-1.cp1198           installed
cpanel-perl-532-test-most.noarch               0.37-1.cp1198           installed
cpanel-perl-532-test-name-fromline.noarch      0.13-1.cp1198           installed
cpanel-perl-532-test-needs.noarch              0.002006-1.cp1198       installed
cpanel-perl-532-test-notabs.noarch             2.02-1.cp1198           installed
cpanel-perl-532-test-nowarnings.noarch         1.04-1.cp1198           installed
cpanel-perl-532-test-number-delta.noarch       1.06-1.cp1198           installed
cpanel-perl-532-test-object.noarch             0.08-1.cp1198           installed
cpanel-perl-532-test-output.noarch             1.031-1.cp1198          installed
cpanel-perl-532-test-parallel.noarch           0.20-1.cp1198           installed
cpanel-perl-532-test-pause-permissions.noarch  0.07-1.cp1198           installed
cpanel-perl-532-test-perl-critic.noarch        1.04-1.cp1198           installed
cpanel-perl-532-test-pod.noarch                1.52-1.cp1198           installed
cpanel-perl-532-test-pod-coverage.noarch       1.10-1.cp1198           installed
cpanel-perl-532-test-pod-no404s.noarch         0.02-1.cp1198           installed
cpanel-perl-532-test-portability-files.noarch  0.10-1.cp1198           installed
cpanel-perl-532-test-requires.noarch           0.11-1.cp1198           installed
cpanel-perl-532-test-requires-git.noarch       1.008-1.cp1198          installed
cpanel-perl-532-test-requiresinternet.noarch   0.05-1.cp1198           installed
cpanel-perl-532-test-script.noarch             1.26-1.cp1198           installed
cpanel-perl-532-test-settings.noarch           0.003-1.cp1198          installed
cpanel-perl-532-test-sharedfork.noarch         0.35-1.cp1198           installed
cpanel-perl-532-test-simple.noarch             1.302183-1.cp1198       installed
cpanel-perl-532-test-spec.noarch               0.54-1.cp1198           installed
cpanel-perl-532-test-spelling.noarch           0.25-1.cp1198           installed
cpanel-perl-532-test-subcalls.noarch           1.10-1.cp1198           installed
cpanel-perl-532-test-sys-info.noarch           0.23-1.cp1198           installed
cpanel-perl-532-test-taint.x86_64              1.08-1.cp1198           installed
cpanel-perl-532-test-tcp.noarch                2.22-1.cp1198           installed
cpanel-perl-532-test-tempdir-tiny.noarch       0.018-1.cp1198          installed
cpanel-perl-532-test-time.noarch               0.08-1.cp1198           installed
cpanel-perl-532-test-timer.noarch              2.11-1.cp1198           installed
cpanel-perl-532-test-trap.noarch               0.3.4-1.cp1198          installed
cpanel-perl-532-test-unit.noarch               0.25-1.cp1198           installed
cpanel-perl-532-test-useallmodules.noarch      0.17-1.cp1198           installed
cpanel-perl-532-test-utf8.noarch               1.01-1.cp1198           installed
cpanel-perl-532-test-version.noarch            2.09-1.cp1198           installed
cpanel-perl-532-test-warn.noarch               0.36-1.cp1198           installed
cpanel-perl-532-test-warnings.noarch           0.030-1.cp1198          installed
cpanel-perl-532-test-without-module.noarch     0.20-1.cp1198           installed
cpanel-perl-532-test-www-mechanize.noarch      1.52-1.cp1198           installed
cpanel-perl-532-test-www-mechanize-catalyst.noarch
                                               0.62-1.cp1198           installed
cpanel-perl-532-test-www-mechanize-cgiapp.noarch
                                               0.05-1.cp1198           installed
cpanel-perl-532-test-www-mechanize-psgi.noarch 0.39-1.cp1198           installed
cpanel-perl-532-test-www-selenium.noarch       1.36-1.cp1198           installed
cpanel-perl-532-test-xhtml.noarch              0.13-1.cp1198           installed
cpanel-perl-532-test-xml.noarch                0.08-1.cp1198           installed
cpanel-perl-532-test-yaml.noarch               1.07-1.cp1198           installed
cpanel-perl-532-test-yaml-valid.noarch         0.04-1.cp1198           installed
cpanel-perl-532-test2-harness.x86_64           1.000038-2.cp1198       installed
cpanel-perl-532-test2-harness-renderer-junit.noarch
                                               1.000004-1.cp1198       installed
cpanel-perl-532-test2-plugin-ioevents.noarch   0.001001-1.cp1198       installed
cpanel-perl-532-test2-plugin-memusage.noarch   0.002003-1.cp1198       installed
cpanel-perl-532-test2-plugin-nowarnings.noarch 0.09-1.cp1198           installed
cpanel-perl-532-test2-plugin-uuid.noarch       0.002001-1.cp1198       installed
cpanel-perl-532-test2-suite.noarch             0.000138-1.cp1198       installed
cpanel-perl-532-test2-tools-explain.noarch     0.02-1.cp1198           installed
cpanel-perl-532-testrail-api.noarch            0.049-1.cp1198          installed
cpanel-perl-532-text-autoformat.noarch         1.75-1.cp1198           installed
cpanel-perl-532-text-control.noarch            0.5-1.cp1198            installed
cpanel-perl-532-text-csv.noarch                2.00-1.cp1198           installed
cpanel-perl-532-text-csv.xs.x86_64             1.44-1.cp1198           installed
cpanel-perl-532-text-dice.noarch               0.06-1.cp1198           installed
cpanel-perl-532-text-diff.noarch               1.45-1.cp1198           installed
cpanel-perl-532-text-extract-maketextcallphrases.noarch
                                               0.94-1.cp1198           installed
cpanel-perl-532-text-fold.noarch               0.5-1.cp1198            installed
cpanel-perl-532-text-german.noarch             0.06-1.cp1198           installed
cpanel-perl-532-text-glob.noarch               0.11-1.cp1198           installed
cpanel-perl-532-text-iconv.x86_64              1.7-1.cp1198            installed
cpanel-perl-532-text-indent.noarch             0.03-1.cp1198           installed
cpanel-perl-532-text-markdown.noarch           1.000031-1.cp1198       installed
cpanel-perl-532-text-microtemplate.noarch      0.24-1.cp1198           installed
cpanel-perl-532-text-multimarkdown.noarch      1.000035-1.cp1198       installed
cpanel-perl-532-text-reform.noarch             1.20-1.cp1198           installed
cpanel-perl-532-text-simpletable.noarch        2.07-1.cp1198           installed
cpanel-perl-532-text-soundex.x86_64            3.05-1.cp1198           installed
cpanel-perl-532-text-template.noarch           1.59-1.cp1198           installed
cpanel-perl-532-text-template-simple.noarch    0.91-1.cp1198           installed
cpanel-perl-532-text-trim.noarch               1.03-1.cp1198           installed
cpanel-perl-532-text-unidecode.noarch          1.30-1.cp1198           installed
cpanel-perl-532-text-xslate.x86_64             3.5.8-1.cp1198          installed
cpanel-perl-532-throwable.noarch               0.200013-1.cp1198       installed
cpanel-perl-532-tie-dbi.noarch                 1.08-1.cp1198           installed
cpanel-perl-532-tie-encryptedhash.noarch       1.24-1.cp1198           installed
cpanel-perl-532-tie-ixhash.noarch              1.23-1.cp1198           installed
cpanel-perl-532-tie-refhash-weak.noarch        0.09-1.cp1198           installed
cpanel-perl-532-tie-shadowhash.noarch          1.00-1.cp1198           installed
cpanel-perl-532-tie-toobject.noarch            0.03-1.cp1198           installed
cpanel-perl-532-time-duration.noarch           1.21-1.cp1198           installed
cpanel-perl-532-time-duration-parse.noarch     0.15-1.cp1198           installed
cpanel-perl-532-time-fake.noarch               0.11-1.cp1198           installed
cpanel-perl-532-time-local.noarch              1.30-1.cp1198           installed
cpanel-perl-532-time-out.noarch                0.11-1.cp1198           installed
cpanel-perl-532-timedate.noarch                2.33-1.cp1198           installed
cpanel-perl-532-tree-dag.node.noarch           1.31-1.cp1198           installed
cpanel-perl-532-tree-multinode.noarch          1.0.13-1.cp1198         installed
cpanel-perl-532-tree-simple.noarch             1.33-1.cp1198           installed
cpanel-perl-532-tree-simple-visitorfactory.noarch
                                               0.15-1.cp1198           installed
cpanel-perl-532-try.x86_64                     0.03-1.cp1198           installed
cpanel-perl-532-try-tiny.noarch                0.30-1.cp1198           installed
cpanel-perl-532-type-tiny.noarch               1.012000-1.cp1198       installed
cpanel-perl-532-types-datetime.noarch          0.002-1.cp1198          installed
cpanel-perl-532-types-path-tiny.noarch         0.006-1.cp1198          installed
cpanel-perl-532-types-serialiser.noarch        1.0-2.cp1198            installed
cpanel-perl-532-ubic.noarch                    1.60-1.cp1198           installed
cpanel-perl-532-ubic-service-initscriptwrapper.noarch
                                               0.02-1.cp1198           installed
cpanel-perl-532-umask-local.noarch             1.0-1.cp1198            installed
cpanel-perl-532-unicode-linebreak.x86_64       2019.001-1.cp1198       installed
cpanel-perl-532-unicode-utf8.x86_64            0.62-1.cp1198           installed
cpanel-perl-532-universal-can.noarch           1.20140328-1.cp1198     installed
cpanel-perl-532-universal-isa.noarch           1.20171012-1.cp1198     installed
cpanel-perl-532-unix-pid.noarch                0.23-1.cp1198           installed
cpanel-perl-532-unix-pid-tiny.noarch           0.95-1.cp1198           installed
cpanel-perl-532-unix-processors.x86_64         2.046-1.cp1198          installed
cpanel-perl-532-unix-sysexits.x86_64           0.06-1.cp1198           installed
cpanel-perl-532-unix-syslog.x86_64             1.1-1.cp1198            installed
cpanel-perl-532-unix-whereis.noarch            0.1-1.cp1198            installed
cpanel-perl-532-uri.noarch                     5.05-1.cp1198           installed
cpanel-perl-532-uri-cpan.noarch                1.007-1.cp1198          installed
cpanel-perl-532-uri-encode.noarch              1.1.1-1.cp1198          installed
cpanel-perl-532-uri-escape-xs.x86_64           0.14-1.cp1198           installed
cpanel-perl-532-uri-find.noarch                20160806-1.cp1198       installed
cpanel-perl-532-uri-fromhash.noarch            0.05-1.cp1198           installed
cpanel-perl-532-uri-template.noarch            0.24-1.cp1198           installed
cpanel-perl-532-uri-ws.noarch                  0.03-1.cp1198           installed
cpanel-perl-532-uri-xsescape.x86_64            0.002000-1.cp1198       installed
cpanel-perl-532-url-encode.noarch              0.03-1.cp1198           installed
cpanel-perl-532-url-encode-xs.x86_64           0.03-1.cp1198           installed
cpanel-perl-532-uuid-tiny.noarch               1.04-1.cp1198           installed
cpanel-perl-532-variable-magic.x86_64          0.62-1.cp1198           installed
cpanel-perl-532-version-next.noarch            1.000-1.cp1198          installed
cpanel-perl-532-version-requirements.noarch    0.101023-1.cp1198       installed
cpanel-perl-532-want.x86_64                    0.29-1.cp1198           installed
cpanel-perl-532-warnings-unused.x86_64         0.06-1.cp1198           installed
cpanel-perl-532-web-detect.noarch              0.05-1.cp1198           installed
cpanel-perl-532-webservice-amazon-route53.noarch
                                               0.101-1.cp1198          installed
cpanel-perl-532-webservice-client.noarch       1.0001-1.cp1198         installed
cpanel-perl-532-webservice-slack-webapi.noarch 0.15-1.cp1198           installed
cpanel-perl-532-www-form.noarch                1.20-1.cp1198           installed
cpanel-perl-532-www-form-urlencoded.noarch     0.26-1.cp1198           installed
cpanel-perl-532-www-mechanize.noarch           2.02-1.cp1198           installed
cpanel-perl-532-www-mechanize-cached.noarch    1.54-1.cp1198           installed
cpanel-perl-532-www-mechanize-treebuilder.noarch
                                               1.20000-1.cp1198        installed
cpanel-perl-532-www-oauth.noarch               1.000-1.cp1198          installed
cpanel-perl-532-www-pastebin-pastebincom-create.noarch
                                               1.003-1.cp1198          installed
cpanel-perl-532-www-robotrules.noarch          6.02-1.cp1198           installed
cpanel-perl-532-www-salesforce.noarch          0.303-1.cp1198          installed
cpanel-perl-532-www-wunderground-api.noarch    0.09-1.cp1198           installed
cpanel-perl-532-x-tiny.noarch                  0.21-1.cp1198           installed
cpanel-perl-532-xml-catalogs.noarch            1.0.3-1.cp1198          installed
cpanel-perl-532-xml-catalogs-html.noarch       1.0.3-1.cp1198          installed
cpanel-perl-532-xml-dom.noarch                 1.46-1.cp1198           installed
cpanel-perl-532-xml-dumper.noarch              0.81-1.cp1198           installed
cpanel-perl-532-xml-entities.noarch            1.0001-1.cp1198         installed
cpanel-perl-532-xml-generator.noarch           1.04-1.cp1198           installed
cpanel-perl-532-xml-libxml.x86_64              2.0206-1.cp1198         installed
cpanel-perl-532-xml-namespacesupport.noarch    1.12-1.cp1198           installed
cpanel-perl-532-xml-parser.x86_64              2.46-1.cp1198           installed
cpanel-perl-532-xml-parser-lite.noarch         0.722-1.cp1198          installed
cpanel-perl-532-xml-regexp.noarch              0.04-1.cp1198           installed
cpanel-perl-532-xml-sax.noarch                 1.02-2.cp1198           installed
cpanel-perl-532-xml-sax-base.noarch            1.09-2.cp1198           installed
cpanel-perl-532-xml-sax-expat.noarch           0.51-2.cp1198           installed
cpanel-perl-532-xml-semanticdiff.noarch        1.0007-1.cp1198         installed
cpanel-perl-532-xml-simple.noarch              2.25-1.cp1198           installed
cpanel-perl-532-xml-stream.noarch              1.24-1.cp1198           installed
cpanel-perl-532-xml-writer.noarch              0.900-1.cp1198          installed
cpanel-perl-532-xml-xpath.noarch               1.44-1.cp1198           installed
cpanel-perl-532-xml-xpathengine.noarch         0.14-1.cp1198           installed
cpanel-perl-532-xstring.x86_64                 0.005-1.cp1198          installed
cpanel-perl-532-yaml.noarch                    1.30-1.cp1198           installed
cpanel-perl-532-yaml-appconfig.noarch          0.19-1.cp1198           installed
cpanel-perl-532-yaml-libyaml.x86_64            0.82-1.cp1198           installed
cpanel-perl-532-yaml-syck.x86_64               1.34-1.cp1198           installed
cpanel-perl-532-yaml-tiny.noarch               1.73-1.cp1198           installed
cpanel-php-composer.noarch                     2.1.11-1.cp11102        installed
cpanel-php-ioncube.x86_64                      11.0.0-1.cp11102        installed
cpanel-php-sourceguardian.x86_64               12.1.2-4.cp11102        installed
cpanel-php74.x86_64                            7.4.26-4.cp11102        installed
cpanel-php74-auth-sasl.noarch                  1.1.0-1.cp11102         installed
cpanel-php74-cache.noarch                      1.5.6-1.cp11102         installed
cpanel-php74-console-color.noarch              1.0.3-1.cp11102         installed
cpanel-php74-console-table.noarch              1.3.1-1.cp11102         installed
cpanel-php74-content.noarch                    2.0.6-1.cp11102         installed
cpanel-php74-date.noarch                       1.4.7-1.cp11102         installed
cpanel-php74-date-holidays.noarch              0.21.8-1.cp11102        installed
cpanel-php74-date-holidays-australia.noarch    0.2.2-1.cp11102         installed
cpanel-php74-date-holidays-austria.noarch      0.1.6-1.cp11102         installed
cpanel-php74-date-holidays-brazil.noarch       0.1.2-1.cp11102         installed
cpanel-php74-date-holidays-croatia.noarch      0.1.1-1.cp11102         installed
cpanel-php74-date-holidays-czech.noarch        0.1.0-1.cp11102         installed
cpanel-php74-date-holidays-denmark.noarch      0.1.3-1.cp11102         installed
cpanel-php74-date-holidays-englandwales.noarch 0.1.5-1.cp11102         installed
cpanel-php74-date-holidays-finland.noarch      0.1.2-1.cp11102         installed
cpanel-php74-date-holidays-germany.noarch      0.1.2-1.cp11102         installed
cpanel-php74-date-holidays-iceland.noarch      0.1.2-1.cp11102         installed
cpanel-php74-date-holidays-ireland.noarch      0.1.3-1.cp11102         installed
cpanel-php74-date-holidays-italy.noarch        0.1.1-1.cp11102         installed
cpanel-php74-date-holidays-japan.noarch        0.1.3-1.cp11102         installed
cpanel-php74-date-holidays-netherlands.noarch  0.1.4-1.cp11102         installed
cpanel-php74-date-holidays-norway.noarch       0.1.2-1.cp11102         installed
cpanel-php74-date-holidays-phpdotnet.noarch    0.1.2-1.cp11102         installed
cpanel-php74-date-holidays-portugal.noarch     0.1.1-1.cp11102         installed
cpanel-php74-date-holidays-romania.noarch      0.1.2-1.cp11102         installed
cpanel-php74-date-holidays-russia.noarch       0.1.0-1.cp11102         installed
cpanel-php74-date-holidays-sanmarino.noarch    0.1.1-1.cp11102         installed
cpanel-php74-date-holidays-serbia.noarch       0.1.0-1.cp11102         installed
cpanel-php74-date-holidays-slovenia.noarch     0.1.2-1.cp11102         installed
cpanel-php74-date-holidays-spain.noarch        0.1.4-1.cp11102         installed
cpanel-php74-date-holidays-sweden.noarch       0.1.3-1.cp11102         installed
cpanel-php74-date-holidays-turkey.noarch       0.1.1-1.cp11102         installed
cpanel-php74-date-holidays-ukraine.noarch      0.1.2-1.cp11102         installed
cpanel-php74-date-holidays-uno.noarch          0.1.3-1.cp11102         installed
cpanel-php74-date-holidays-usa.noarch          0.1.1-1.cp11102         installed
cpanel-php74-date-holidays-venezuela.noarch    0.1.1-1.cp11102         installed
cpanel-php74-db.noarch                         1.9.3-1.cp11102         installed
cpanel-php74-file.noarch                       1.4.1-1.cp11102         installed
cpanel-php74-file-find.noarch                  1.3.3-1.cp11102         installed
cpanel-php74-file-fstab.noarch                 2.0.3-1.cp11102         installed
cpanel-php74-horde.noarch                      5.2.23-3.cp11102        installed
cpanel-php74-horde-alarm.noarch                2.2.10-1.cp11102        installed
cpanel-php74-horde-argv.noarch                 2.1.0-1.cp11102         installed
cpanel-php74-horde-auth.noarch                 2.2.2-1.cp11102         installed
cpanel-php74-horde-autoloader.noarch           2.1.2-1.cp11102         installed
cpanel-php74-horde-browser.noarch              2.0.16-1.cp11102        installed
cpanel-php74-horde-cache.noarch                2.5.5-1.cp11102         installed
cpanel-php74-horde-cli.noarch                  2.3.0-1.cp11102         installed
cpanel-php74-horde-compress.noarch             2.2.4-1.cp11102         installed
cpanel-php74-horde-compress-fast.noarch        1.1.1-1.cp11102         installed
cpanel-php74-horde-constraint.noarch           2.0.3-1.cp11102         installed
cpanel-php74-horde-controller.noarch           2.0.5-1.cp11102         installed
cpanel-php74-horde-core.noarch                 2.31.16-1.cp11102       installed
cpanel-php74-horde-crypt.noarch                2.7.12-1.cp11102        installed
cpanel-php74-horde-crypt-blowfish.noarch       1.1.3-1.cp11102         installed
cpanel-php74-horde-css-parser.noarch           1.0.11-1.cp11102        installed
cpanel-php74-horde-cssminify.noarch            1.0.4-1.cp11102         installed
cpanel-php74-horde-data.noarch                 2.1.5-1.cp11102         installed
cpanel-php74-horde-date.noarch                 2.4.1-1.cp11102         installed
cpanel-php74-horde-date-parser.noarch          2.0.7-1.cp11102         installed
cpanel-php74-horde-dav.noarch                  1.1.4-1.cp11102         installed
cpanel-php74-horde-db.noarch                   2.4.1-1.cp11102         installed
cpanel-php74-horde-editor.noarch               2.0.5-1.cp11102         installed
cpanel-php74-horde-elasticsearch.noarch        1.0.4-1.cp11102         installed
cpanel-php74-horde-exception.noarch            2.0.8-1.cp11102         installed
cpanel-php74-horde-feed.noarch                 2.0.4-1.cp11102         installed
cpanel-php74-horde-form.noarch                 2.0.20-1.cp11102        installed
cpanel-php74-horde-group.noarch                2.1.1-1.cp11102         installed
cpanel-php74-horde-hashtable.noarch            1.2.6-1.cp11102         installed
cpanel-php74-horde-history.noarch              2.3.6-1.cp11102         installed
cpanel-php74-horde-http.noarch                 2.1.7-1.cp11102         installed
cpanel-php74-horde-icalendar.noarch            2.1.8-1.cp11102         installed
cpanel-php74-horde-idna.noarch                 1.1.2-1.cp11102         installed
cpanel-php74-horde-image.noarch                2.6.1-1.cp11102         installed
cpanel-php74-horde-imap-client.noarch          2.29.17-1.cp11102       installed
cpanel-php74-horde-imsp.noarch                 2.0.10-1.cp11102        installed
cpanel-php74-horde-injector.noarch             2.0.5-1.cp11102         installed
cpanel-php74-horde-itip.noarch                 2.1.2-1.cp11102         installed
cpanel-php74-horde-javascriptminify.noarch     1.1.5-1.cp11102         installed
cpanel-php74-horde-kolab-format.noarch         2.0.9-1.cp11102         installed
cpanel-php74-horde-kolab-session.noarch        2.0.3-1.cp11102         installed
cpanel-php74-horde-listheaders.noarch          1.2.5-1.cp11102         installed
cpanel-php74-horde-lock.noarch                 2.1.4-1.cp11102         installed
cpanel-php74-horde-log.noarch                  2.3.0-1.cp11102         installed
cpanel-php74-horde-logintasks.noarch           2.0.7-1.cp11102         installed
cpanel-php74-horde-mail.noarch                 2.6.5-1.cp11102         installed
cpanel-php74-horde-mail-autoconfig.noarch      1.0.3-1.cp11102         installed
cpanel-php74-horde-mime.noarch                 2.11.1-1.cp11102        installed
cpanel-php74-horde-mime-viewer.noarch          2.2.2-1.cp11102         installed
cpanel-php74-horde-nls.noarch                  2.2.1-1.cp11102         installed
cpanel-php74-horde-notification.noarch         2.0.4-1.cp11102         installed
cpanel-php74-horde-oauth.noarch                2.0.4-1.cp11102         installed
cpanel-php74-horde-pack.noarch                 1.0.7-1.cp11102         installed
cpanel-php74-horde-pdf.noarch                  2.0.8-1.cp11102         installed
cpanel-php74-horde-perms.noarch                2.1.8-1.cp11102         installed
cpanel-php74-horde-prefs.noarch                2.9.0-1.cp11102         installed
cpanel-php74-horde-queue.noarch                1.1.5-1.cp11102         installed
cpanel-php74-horde-rdo.noarch                  2.1.0-1.cp11102         installed
cpanel-php74-horde-role.noarch                 1.0.1-1.cp11102         installed
cpanel-php74-horde-routes.noarch               2.0.5-1.cp11102         installed
cpanel-php74-horde-rpc.noarch                  2.1.9-1.cp11102         installed
cpanel-php74-horde-secret.noarch               2.0.6-1.cp11102         installed
cpanel-php74-horde-serialize.noarch            2.0.5-1.cp11102         installed
cpanel-php74-horde-service-facebook.noarch     2.0.10-1.cp11102        installed
cpanel-php74-horde-service-twitter.noarch      2.1.6-1.cp11102         installed
cpanel-php74-horde-sessionhandler.noarch       2.3.0-1.cp11102         installed
cpanel-php74-horde-share.noarch                2.2.0-1.cp11102         installed
cpanel-php74-horde-smtp.noarch                 1.9.6-1.cp11102         installed
cpanel-php74-horde-socket-client.noarch        2.1.3-1.cp11102         installed
cpanel-php74-horde-spellchecker.noarch         2.1.3-1.cp11102         installed
cpanel-php74-horde-stream.noarch               1.6.3-1.cp11102         installed
cpanel-php74-horde-stream-filter.noarch        2.0.4-1.cp11102         installed
cpanel-php74-horde-stream-wrapper.noarch       2.1.4-1.cp11102         installed
cpanel-php74-horde-support.noarch              2.2.0-1.cp11102         installed
cpanel-php74-horde-syncml.noarch               2.0.7-1.cp11102         installed
cpanel-php74-horde-template.noarch             2.0.3-1.cp11102         installed
cpanel-php74-horde-text-diff.noarch            2.2.1-1.cp11102         installed
cpanel-php74-horde-text-filter.noarch          2.3.7-1.cp11102         installed
cpanel-php74-horde-text-flowed.noarch          2.0.4-1.cp11102         installed
cpanel-php74-horde-timezone.noarch             1.1.0-1.cp11102         installed
cpanel-php74-horde-token.noarch                2.0.9-1.cp11102         installed
cpanel-php74-horde-translation.noarch          2.2.2-1.cp11102         installed
cpanel-php74-horde-tree.noarch                 2.0.5-1.cp11102         installed
cpanel-php74-horde-url.noarch                  2.2.6-1.cp11102         installed
cpanel-php74-horde-util.noarch                 2.5.9-1.cp11102         installed
cpanel-php74-horde-vfs.noarch                  2.4.1-1.cp11102         installed
cpanel-php74-horde-view.noarch                 2.0.6-1.cp11102         installed
cpanel-php74-horde-xml-element.noarch          2.0.4-1.cp11102         installed
cpanel-php74-horde-xml-wbxml.noarch            2.0.4-1.cp11102         installed
cpanel-php74-horde-yaml.noarch                 2.1.0-1.cp11102         installed
cpanel-php74-html-template-it.noarch           1.3.1-1.cp11102         installed
cpanel-php74-http.noarch                       1.4.1-1.cp11102         installed
cpanel-php74-http-request.noarch               1.4.4-1.cp11102         installed
cpanel-php74-http-webdav-server.noarch         1.0.0-1.cp11102         installed
cpanel-php74-imp.noarch                        6.2.27-1.cp11102        installed
cpanel-php74-ingo.noarch                       3.2.16-1.cp11102        installed
cpanel-php74-kronolith.noarch                  4.2.29-1.cp11102        installed
cpanel-php74-log.noarch                        1.13.1-1.cp11102        installed
cpanel-php74-mail.noarch                       1.4.1-1.cp11102         installed
cpanel-php74-mail-mime.noarch                  1.10.2-1.cp11102        installed
cpanel-php74-mdb2.noarch                       2.4.1-1.cp11102         installed
cpanel-php74-mnemo.noarch                      4.2.14-1.cp11102        installed
cpanel-php74-nag.noarch                        4.2.19-1.cp11102        installed
cpanel-php74-net-dns2.noarch                   1.4.4-1.cp11102         installed
cpanel-php74-net-ftp.noarch                    1.4.0-1.cp11102         installed
cpanel-php74-net-imap.noarch                   1.1.3-1.cp11102         installed
cpanel-php74-net-sieve.noarch                  1.4.4-1.cp11102         installed
cpanel-php74-net-smtp.noarch                   1.8.1-1.cp11102         installed
cpanel-php74-net-socket.noarch                 1.2.2-1.cp11102         installed
cpanel-php74-net-url.noarch                    1.0.15-1.cp11102        installed
cpanel-php74-net-useragent-detect.noarch       2.5.2-1.cp11102         installed
cpanel-php74-pear-command-packaging.noarch     0.3.0-1.cp11102         installed
cpanel-php74-services-weather.noarch           1.4.7-1.cp11102         installed
cpanel-php74-soap.noarch                       0.14.0-1.cp11102        installed
cpanel-php74-text-figlet.noarch                1.0.2-1.cp11102         installed
cpanel-php74-timeobjects.noarch                2.1.4-1.cp11102         installed
cpanel-php74-trean.noarch                      1.1.10-1.cp11102        installed
cpanel-php74-turba.noarch                      4.2.25-1.cp11102        installed
cpanel-php74-webmail.noarch                    5.2.22-1.cp11102        installed
cpanel-php74-xml-parser.noarch                 1.3.8-1.cp11102         installed
cpanel-php74-xml-rpc.noarch                    1.5.5-1.cp11102         installed
cpanel-php74-xml-serializer.noarch             0.21.0-1.cp11102        installed
cpanel-php74-xml-svg.noarch                    1.1.0-1.cp11102         installed
cpanel-phpmyadmin.noarch                       4.9.7-1.cp11102         installed
cpanel-phppgadmin.noarch                       5.6.0-1.cp11102         installed
cpanel-pigz.x86_64                             2.4-1.cp1198            installed
cpanel-postgresql.x86_64                       9.2.24-1.cp1198         installed
cpanel-postgresql-devel.x86_64                 9.2.24-1.cp1198         installed
cpanel-postgresql-libs.x86_64                  9.2.24-1.cp1198         installed
cpanel-promise-polyfill-js-v3.5.noarch         3.5.5-1.cp1198          installed
cpanel-punycodejs.noarch                       1.4.1-1.cp1198          installed
cpanel-puttygen.x86_64                         0.75-1.cp1198           installed
cpanel-pythontidy.noarch                       1.22-1.cp1198           installed
cpanel-qrcodejs.noarch                         0.0.1-1.cp1198          installed
cpanel-re2c.x86_64                             2.2-1.cp11100           installed
cpanel-remixicons.noarch                       2.5.0-1.cp1198          installed
cpanel-requirejs.noarch                        2.1.14-1.cp1198         installed
cpanel-requirejs-devel.noarch                  2.1.14-1.cp1198         installed
cpanel-roboto.noarch                           2.138-1.cp1198          installed
cpanel-roundcubemail.noarch                    1.4.12-1.cp1198         installed
cpanel-rpmlint-configs.noarch                  1.0-3.cp1160.3.cpanel   @cp-dev-tools
cpanel-rrdflot.noarch                          1.1.0-1.cp1198          installed
cpanel-rrdtool.x86_64                          1.5.5-1.cp1198          installed
cpanel-rrdtool-devel.x86_64                    1.5.5-1.cp1198          installed
cpanel-site-publisher-templates.noarch         1.0-1.cp1198            installed
cpanel-splitlogs.x86_64                        1.0-1.cp1198            installed
cpanel-sqlite.x86_64                           3.32.3-1.cp1198         installed
cpanel-sqlite-devel.x86_64                     3.32.3-1.cp1198         installed
cpanel-system-python27.x86_64                  2.7.7-1.cp1198          installed
cpanel-trigger-os-release.noarch               1.2-1.cp1198            installed
cpanel-unbound.x86_64                          1.13.2-1.cp1198         installed
cpanel-userperl.x86_64                         1.0-2.cp1198            installed
cpanel-webalizer.x86_64                        2.23.08-2.cp1198        installed
cpanel-wrap.x86_64                             98.2-1.cp1198           installed
cpanel-xdelta3.x86_64                          3.0.11-1.cp1198         installed
cpanel-xtermjs.noarch                          3.3.0-1.cp1198          installed
cpanel-yarn.noarch                             1.22.5-1.cp1198         installed
cpanel-yui.noarch                              2.9.0-1.cp1198          installed
cpio.x86_64                                    2.11-28.el7             @base    
cpp.x86_64                                     4.8.5-44.el7            @base    
cracklib.x86_64                                2.9.0-11.el7            installed
cracklib-dicts.x86_64                          2.9.0-11.el7            installed
cronie.x86_64                                  1.4.11-24.el7_9         @updates 
cronie-anacron.x86_64                          1.4.11-24.el7_9         @updates 
crontabs.noarch                                1.11-6.20121102git.el7  installed
cryptsetup-libs.x86_64                         2.0.3-6.el7             installed
ctags.x86_64                                   5.8-13.el7              @base    
ctags-etags.x86_64                             5.8-13.el7              @base    
cups-client.x86_64                             1:1.6.3-51.el7          @base    
cups-libs.x86_64                               1:1.6.3-51.el7          @base    
curl.x86_64                                    7.29.0-59.el7_9.1       @updates 
cvs.x86_64                                     1.11.23-35.el7          @base    
cyrus-sasl.x86_64                              2.1.26-23.el7           @base    
cyrus-sasl-devel.x86_64                        2.1.26-23.el7           @base    
cyrus-sasl-lib.x86_64                          2.1.26-23.el7           installed
davix-libs.x86_64                              0.8.0-1.el7             @epel    
dbus.x86_64                                    1:1.10.24-15.el7        @base    
dbus-glib.x86_64                               0.100-7.el7             installed
dbus-libs.x86_64                               1:1.10.24-15.el7        @base    
dbus-python.x86_64                             1.1.1-9.el7             installed
dconf.x86_64                                   0.28.0-4.el7            @base    
dejavu-fonts-common.noarch                     2.33-6.el7              @base    
dejavu-sans-fonts.noarch                       2.33-6.el7              @base    
desktop-file-utils.x86_64                      0.23-2.el7              @base    
device-mapper.x86_64                           7:1.02.170-6.el7_9.5    @updates 
device-mapper-event.x86_64                     7:1.02.170-6.el7_9.5    @updates 
device-mapper-event-libs.x86_64                7:1.02.170-6.el7_9.5    @updates 
device-mapper-libs.x86_64                      7:1.02.170-6.el7_9.5    @updates 
device-mapper-persistent-data.x86_64           0.8.5-3.el7_9.2         @updates 
devscripts.x86_64                              2.16.5-2.el7            @epel    
devscripts-minimal.x86_64                      2.16.5-2.el7            @epel    
dhclient.x86_64                                12:4.2.5-83.el7.centos.1
                                                                       @updates 
dhcp-common.x86_64                             12:4.2.5-83.el7.centos.1
                                                                       @updates 
dhcp-libs.x86_64                               12:4.2.5-83.el7.centos.1
                                                                       @updates 
diffutils.x86_64                               3.3-5.el7               installed
dmidecode.x86_64                               1:3.2-5.el7_9.1         @updates 
docbook-dtds.noarch                            1.0-60.el7              @base    
docbook-style-xsl.noarch                       1.78.1-3.el7            @base    
dpkg.x86_64                                    1.18.25-9.el7           @epel    
dpkg.x86_64                                    1.18.25-10.el7          installed
dpkg-dev.noarch                                1.18.25-10.el7          installed
dpkg-perl.noarch                               1.18.25-10.el7          installed
dracut.x86_64                                  033-572.el7             @base    
dracut-config-generic.x86_64                   033-572.el7             @base    
dracut-config-rescue.x86_64                    033-572.el7             @base    
dracut-network.x86_64                          033-572.el7             @base    
dwz.x86_64                                     0.11-3.el7              @base    
e2fsprogs.x86_64                               1.42.9-19.el7           @base    
e2fsprogs-devel.x86_64                         1.42.9-19.el7           @base    
e2fsprogs-libs.x86_64                          1.42.9-19.el7           @base    
ea-apache24.x86_64                             2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apache24-config.noarch                      1.0-181.211.1.cpanel    @EA4-developer-feed
ea-apache24-config-runtime.noarch              1.0-181.211.1.cpanel    @EA4-developer-feed
ea-apache24-mod_bwlimited.x86_64               1.4-47.54.8.cpanel      @EA4-developer-feed
ea-apache24-mod_cgi.x86_64                     2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apache24-mod_deflate.x86_64                 2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apache24-mod_expires.x86_64                 2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apache24-mod_headers.x86_64                 2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apache24-mod_mpm_prefork.x86_64             2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apache24-mod_proxy.x86_64                   2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apache24-mod_proxy_fcgi.x86_64              2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apache24-mod_proxy_http.x86_64              2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apache24-mod_proxy_wstunnel.x86_64          2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apache24-mod_ruid2.x86_64                   0.9.8-19.25.8.cpanel    @EA4-developer-feed
ea-apache24-mod_security2.x86_64               2.9.4-2.2.1.cpanel      @EA4-developer-feed
ea-apache24-mod_ssl.x86_64                     2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apache24-mod_unique_id.x86_64               2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apache24-tools.x86_64                       2.4.52-2.3.1.cpanel     @EA4-developer-feed
ea-apr.x86_64                                  1.7.0-6.10.3.cpanel     @EA4-developer-feed
ea-apr-util.x86_64                             1.6.1-8.12.4.cpanel     @EA4-developer-feed
ea-brotli.x86_64                               1.0.9-1.1.3.cpanel      @EA4     
ea-cpanel-tools.x86_64                         1.0-52.65.1.cpanel      @EA4-developer-feed
ea-documentroot.noarch                         1.0-6.9.1.cpanel        @EA4-developer-feed
ea-libargon2.x86_64                            20161029-3.3.7.cpanel   @EA4-developer-feed
ea-libcurl.x86_64                              7.81.0-1.1.1.cpanel     @EA4-developer-feed
ea-libnghttp2.x86_64                           1.46.0-1.1.3.cpanel     @EA4-developer-feed
ea-libxml2.x86_64                              2.9.7-4.4.5.cpanel      @EA4-developer-feed
ea-modsec-sdbm-util.x86_64                     0.02-2.5.4.cpanel       @EA4-developer-feed
ea-nghttp2.x86_64                              1.46.0-1.1.3.cpanel     @EA4-developer-feed
ea-oniguruma.x86_64                            6.9.7.1-1.1.1.cpanel    @EA4-developer-feed
ea-oniguruma-devel.x86_64                      6.9.7.1-1.1.1.cpanel    @EA4-developer-feed
ea-openssl11.x86_64                            1.1.1m-2.2.1.cpanel     @EA4-developer-feed
ea-php-cli.x86_64                              1.0.0-9.12.1.cpanel     @EA4-developer-feed
ea-php-cli-lsphp.x86_64                        1.0.0-9.12.1.cpanel     @EA4-developer-feed
ea-php73.x86_64                                7.3.33-1.1.1.cpanel     @EA4-developer-feed
ea-php73-libc-client.x86_64                    2007f-22.24.2.cpanel    @EA4-developer-feed
ea-php73-pear.noarch                           1.10.12-4.23.6.cpanel   @EA4-developer-feed
ea-php73-php-bcmath.x86_64                     7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-calendar.x86_64                   7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-cli.x86_64                        7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-common.x86_64                     7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-curl.x86_64                       7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-devel.x86_64                      7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-fpm.x86_64                        7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-ftp.x86_64                        7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-gd.x86_64                         7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-iconv.x86_64                      7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-imap.x86_64                       7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-litespeed.x86_64                  7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-mbstring.x86_64                   7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-mysqlnd.x86_64                    7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-pdo.x86_64                        7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-posix.x86_64                      7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-sockets.x86_64                    7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-php-xml.x86_64                        7.3.33-3.4.1.cpanel     @EA4-developer-feed
ea-php73-runtime.x86_64                        7.3.33-1.1.1.cpanel     @EA4-developer-feed
ea-php74.x86_64                                7.4.27-1.2.1.cpanel     @EA4-developer-feed
ea-php74-libc-client.x86_64                    2007f-22.23.2.cpanel    @EA4-developer-feed
ea-php74-pear.noarch                           1.10.12-4.26.8.cpanel   @EA4-developer-feed
ea-php74-php-bcmath.x86_64                     7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-calendar.x86_64                   7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-cli.x86_64                        7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-common.x86_64                     7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-curl.x86_64                       7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-devel.x86_64                      7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-fpm.x86_64                        7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-ftp.x86_64                        7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-gd.x86_64                         7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-iconv.x86_64                      7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-imap.x86_64                       7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-litespeed.x86_64                  7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-mbstring.x86_64                   7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-mysqlnd.x86_64                    7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-pdo.x86_64                        7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-posix.x86_64                      7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-sockets.x86_64                    7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-php-xml.x86_64                        7.4.27-4.9.4.cpanel     @EA4-developer-feed
ea-php74-runtime.x86_64                        7.4.27-1.2.1.cpanel     @EA4-developer-feed
ea-php80.x86_64                                8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-libc-client.x86_64                    2007f-22.23.2.cpanel    @EA4-developer-feed
ea-php80-pear.noarch                           1.10.12-4.22.8.cpanel   @EA4-developer-feed
ea-php80-php-bcmath.x86_64                     8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-calendar.x86_64                   8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-cli.x86_64                        8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-common.x86_64                     8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-curl.x86_64                       8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-devel.x86_64                      8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-fpm.x86_64                        8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-ftp.x86_64                        8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-gd.x86_64                         8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-iconv.x86_64                      8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-imap.x86_64                       8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-litespeed.x86_64                  8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-mbstring.x86_64                   8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-mysqlnd.x86_64                    8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-pdo.x86_64                        8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-posix.x86_64                      8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-sockets.x86_64                    8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-php-xml.x86_64                        8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-php80-runtime.x86_64                        8.0.15-1.1.1.cpanel     @EA4-developer-feed
ea-profiles-cpanel.x86_64                      1.0-57.72.1.cpanel      @EA4-developer-feed
ebtables.x86_64                                2.0.10-16.el7           @base    
ed.x86_64                                      1.9-4.el7               @base    
elfutils.x86_64                                0.176-5.el7             @base    
elfutils-default-yama-scope.noarch             0.176-5.el7             @base    
elfutils-libelf.x86_64                         0.176-5.el7             @base    
elfutils-libs.x86_64                           0.176-5.el7             @base    
elinks.x86_64                                  0.12-0.37.pre6.el7.0.1  @updates 
emacs-common.x86_64                            1:24.3-23.el7           @base    
emacs-filesystem.noarch                        1:24.3-23.el7           @base    
emacs-nox.x86_64                               1:24.3-23.el7           @base    
enchant.x86_64                                 1:1.6.0-8.el7           @base    
epel-release.noarch                            7-14                    @epel    
ethtool.x86_64                                 2:4.8-10.el7            installed
expat.x86_64                                   2.1.0-12.el7            @base    
expat-devel.x86_64                             2.1.0-12.el7            @base    
expect.x86_64                                  5.45-14.el7_1           @base    
fakeroot.x86_64                                1.26-4.el7              @epel    
fakeroot-libs.x86_64                           1.26-4.el7              @epel    
file.x86_64                                    5.11-37.el7             @base    
file-libs.x86_64                               5.11-37.el7             @base    
filesystem.x86_64                              3.2-25.el7              installed
findutils.x86_64                               1:4.5.11-6.el7          installed
finger.x86_64                                  0.17-52.el7             @base    
fipscheck.x86_64                               1.4.1-6.el7             installed
fipscheck-lib.x86_64                           1.4.1-6.el7             installed
firewalld.noarch                               0.6.3-13.el7_9          @updates 
firewalld-filesystem.noarch                    0.6.3-13.el7_9          @updates 
flex.x86_64                                    2.5.37-6.el7            @base    
fontconfig.x86_64                              2.13.0-4.3.el7          @base    
fontconfig-devel.x86_64                        2.13.0-4.3.el7          @base    
fontpackages-filesystem.noarch                 1.44-8.el7              @base    
freetype.x86_64                                2.8-14.el7_9.1          @updates 
freetype-devel.x86_64                          2.8-14.el7_9.1          @updates 
fribidi.x86_64                                 1.0.2-1.el7_7.1         @base    
ftp.x86_64                                     0.17-67.el7             @base    
fxload.x86_64                                  2002_04_11-16.el7       @base    
gamin.x86_64                                   0.1.10-16.el7           @base    
gamin-devel.x86_64                             0.1.10-16.el7           @base    
gawk.x86_64                                    4.0.2-4.el7_3.1         installed
gcc.x86_64                                     4.8.5-44.el7            @base    
gcc-c++.x86_64                                 4.8.5-44.el7            @base    
gd.x86_64                                      2.0.35-27.el7_9         @updates 
gd-devel.x86_64                                2.0.35-27.el7_9         @updates 
gd-progs.x86_64                                2.0.35-27.el7_9         @updates 
gdb.x86_64                                     7.6.1-120.el7           @base    
gdbm.x86_64                                    1.10-8.el7              installed
gdbm-devel.x86_64                              1.10-8.el7              @base    
gdisk.x86_64                                   0.8.10-3.el7            @base    
gdk-pixbuf2.x86_64                             2.36.12-3.el7           @base    
geoipupdate.x86_64                             2.5.0-1.el7             @base    
gettext.x86_64                                 0.19.8.1-3.el7          installed
gettext-common-devel.noarch                    0.19.8.1-3.el7          @base    
gettext-devel.x86_64                           0.19.8.1-3.el7          @base    
gettext-libs.x86_64                            0.19.8.1-3.el7          installed
ghostscript.x86_64                             9.25-5.el7              @base    
ghostscript-fonts.noarch                       5.50-32.el7             @base    
giflib.x86_64                                  4.1.6-9.el7             @base    
git.x86_64                                     1.8.3.1-23.el7_8        @base    
glib-networking.x86_64                         2.56.1-1.el7            @base    
glib2.x86_64                                   2.56.1-9.el7_9          @updates 
glibc.x86_64                                   2.17-325.el7_9          @updates 
glibc-common.x86_64                            2.17-325.el7_9          @updates 
glibc-devel.x86_64                             2.17-325.el7_9          @updates 
glibc-headers.x86_64                           2.17-325.el7_9          @updates 
glibc-static.x86_64                            2.17-325.el7_9          @updates 
gmp.x86_64                                     1:6.0.0-15.el7          installed
gmp-devel.x86_64                               1:6.0.0-15.el7          @base    
gnu-free-fonts-common.noarch                   20120503-8.el7          @base    
gnu-free-mono-fonts.noarch                     20120503-8.el7          @base    
gnu-free-sans-fonts.noarch                     20120503-8.el7          @base    
gnu-free-serif-fonts.noarch                    20120503-8.el7          @base    
gnupg2.x86_64                                  2.0.22-5.el7_5          installed
gnutls.x86_64                                  3.3.29-9.el7_6          @base    
gobject-introspection.x86_64                   1.56.1-1.el7            installed
google-chrome-stable.x86_64                    97.0.4692.71-1          @google-chrome
google-chrome-stable.x86_64                    97.0.4692.99-1          installed
google-droid-sans-fonts.noarch                 20120715-12.el7         @epel    
gpgme.x86_64                                   1.3.2-5.el7             installed
gpm-libs.x86_64                                1.20.7-6.el7            @base    
graphite2.x86_64                               1.3.10-1.el7_3          @base    
graphviz.x86_64                                2.30.1-22.el7           @base    
grep.x86_64                                    2.20-3.el7              installed
groff.x86_64                                   1.22.2-8.el7            @base    
groff-base.x86_64                              1.22.2-8.el7            installed
groff-perl.x86_64                              1.22.2-8.el7            @base    
grub2.x86_64                                   1:2.02-0.87.el7.centos.7
                                                                       @updates 
grub2-common.noarch                            1:2.02-0.87.el7.centos.7
                                                                       @updates 
grub2-pc.x86_64                                1:2.02-0.87.el7.centos.7
                                                                       @updates 
grub2-pc-modules.noarch                        1:2.02-0.87.el7.centos.7
                                                                       @updates 
grub2-tools.x86_64                             1:2.02-0.87.el7.centos.7
                                                                       @updates 
grub2-tools-extra.x86_64                       1:2.02-0.87.el7.centos.7
                                                                       @updates 
grub2-tools-minimal.x86_64                     1:2.02-0.87.el7.centos.7
                                                                       @updates 
grubby.x86_64                                  8.28-26.el7             installed
gsettings-desktop-schemas.x86_64               3.28.0-3.el7            @base    
gsl.x86_64                                     1.15-13.el7             @base    
gsoap.x86_64                                   2.8.16-12.el7           @epel    
gssproxy.x86_64                                0.7.0-30.el7_9          @updates 
gtk-update-icon-cache.x86_64                   3.22.30-6.el7           @updates 
gtk2.x86_64                                    2.24.31-1.el7           @base    
gtk3.x86_64                                    3.22.30-6.el7           @updates 
gzip.x86_64                                    1.5-10.el7              installed
hardlink.x86_64                                1:1.0-19.el7            installed
harfbuzz.x86_64                                1.7.5-2.el7             @base    
hicolor-icon-theme.noarch                      0.12-7.el7              @base    
hostname.x86_64                                3.13-3.el7_7.1          installed
html2ps.noarch                                 1.0-0.14.b7.el7         @base    
hunspell.x86_64                                1.3.2-16.el7            @base    
hunspell-en.noarch                             0.20121024-6.el7        @base    
hunspell-en-GB.noarch                          0.20121024-6.el7        @base    
hunspell-en-US.noarch                          0.20121024-6.el7        @base    
hwdata.x86_64                                  0.252-9.7.el7           @base    
ilmbase.x86_64                                 1.0.3-7.el7             @base    
indent.x86_64                                  2.2.11-13.el7           @base    
info.x86_64                                    5.1-5.el7               installed
initscripts.x86_64                             9.49.53-1.el7_9.1       @updates 
iproute.x86_64                                 4.11.0-30.el7           @base    
iprutils.x86_64                                2.4.17.1-3.el7_7        @updates 
ipset.x86_64                                   7.1-1.el7               @base    
ipset-libs.x86_64                              7.1-1.el7               @base    
iptables.x86_64                                1.4.21-35.el7           @base    
iptables-services.x86_64                       1.4.21-35.el7           @base    
iputils.x86_64                                 20160308-10.el7         installed
iso-codes.noarch                               3.46-2.el7              @base    
iwl100-firmware.noarch                         39.31.5.1-80.el7_9      @updates 
iwl105-firmware.noarch                         18.168.6.1-80.el7_9     @updates 
iwl135-firmware.noarch                         18.168.6.1-80.el7_9     @updates 
iwl2000-firmware.noarch                        18.168.6.1-80.el7_9     @updates 
iwl2030-firmware.noarch                        18.168.6.1-80.el7_9     @updates 
iwl3160-firmware.noarch                        25.30.13.0-80.el7_9     @updates 
iwl6000g2a-firmware.noarch                     18.168.6.1-80.el7_9     @updates 
iwl6000g2b-firmware.noarch                     18.168.6.1-80.el7_9     @updates 
iwl7260-firmware.noarch                        25.30.13.0-80.el7_9     @updates 
jansson.x86_64                                 2.10-1.el7              installed
jasper-devel.x86_64                            1.900.1-33.el7          @base    
jasper-libs.x86_64                             1.900.1-33.el7          @base    
java-1.8.0-openjdk.x86_64                      1:1.8.0.312.b07-1.el7_9 @updates 
java-1.8.0-openjdk-headless.x86_64             1:1.8.0.312.b07-1.el7_9 @updates 
javapackages-tools.noarch                      3.4.1-11.el7            @base    
jbigkit-libs.x86_64                            2.0-11.el7              @base    
jemalloc.x86_64                                3.6.0-1.el7             @epel    
jitterentropy-rngd.x86_64                      1.0.6-1.el7             @epel    
js.x86_64                                      1:1.8.5-20.el7          @base    
json-c.x86_64                                  0.11-4.el7_0            installed
json-c-devel.x86_64                            0.11-4.el7_0            @base    
json-devel.x86_64                              3.6.1-2.el7             @epel    
json-glib.x86_64                               1.4.2-2.el7             @base    
jwhois.x86_64                                  4.0-47.el7              @epel    
kbd.x86_64                                     1.15.5-16.el7_9         @updates 
kbd-legacy.noarch                              1.15.5-16.el7_9         @updates 
kbd-misc.noarch                                1.15.5-16.el7_9         @updates 
kernel.x86_64                                  3.10.0-1160.42.2.el7    @updates 
kernel.x86_64                                  3.10.0-1160.49.1.el7    @updates 
kernel.x86_64                                  3.10.0-1160.53.1.el7    @updates 
kernel-headers.x86_64                          3.10.0-1160.53.1.el7    @updates 
kernel-tools.x86_64                            3.10.0-1160.53.1.el7    @updates 
kernel-tools-libs.x86_64                       3.10.0-1160.53.1.el7    @updates 
keyutils.x86_64                                1.5.8-3.el7             installed
keyutils-libs.x86_64                           1.5.8-3.el7             installed
keyutils-libs-devel.x86_64                     1.5.8-3.el7             @base    
kmod.x86_64                                    20-28.el7               installed
kmod-libs.x86_64                               20-28.el7               installed
kpartx.x86_64                                  0.4.9-135.el7_9         @updates 
krb5-devel.x86_64                              1.15.1-51.el7_9         @updates 
krb5-libs.x86_64                               1.15.1-51.el7_9         @updates 
lapack.x86_64                                  3.4.2-8.el7             @base    
lcms2.x86_64                                   2.6-3.el7               @base    
less.x86_64                                    458-9.el7               installed
libAfterImage.x86_64                           1.20-21.el7             @epel    
libICE.x86_64                                  1.0.9-9.el7             @base    
libICE-devel.x86_64                            1.0.9-9.el7             @base    
libIDL.x86_64                                  0.8.14-8.el7            @base    
libSM.x86_64                                   1.2.2-2.el7             @base    
libSM-devel.x86_64                             1.2.2-2.el7             @base    
libX11.x86_64                                  1.6.7-4.el7_9           @updates 
libX11-common.noarch                           1.6.7-4.el7_9           @updates 
libX11-devel.x86_64                            1.6.7-4.el7_9           @updates 
libXScrnSaver.x86_64                           1.2.2-6.1.el7           @base    
libXau.x86_64                                  1.0.8-2.1.el7           @base    
libXau-devel.x86_64                            1.0.8-2.1.el7           @base    
libXaw.x86_64                                  1.0.13-4.el7            @base    
libXcomposite.x86_64                           0.4.4-4.1.el7           @base    
libXcursor.x86_64                              1.1.15-1.el7            @base    
libXdamage.x86_64                              1.1.4-4.1.el7           @base    
libXext.x86_64                                 1.3.3-3.el7             @base    
libXext-devel.x86_64                           1.3.3-3.el7             @base    
libXfixes.x86_64                               5.0.3-1.el7             @base    
libXfont.x86_64                                1.5.4-1.el7             @base    
libXft.x86_64                                  2.3.2-2.el7             @base    
libXi.x86_64                                   1.7.9-1.el7             @base    
libXinerama.x86_64                             1.1.3-2.1.el7           @base    
libXmu.x86_64                                  1.1.2-2.el7             @base    
libXpm.x86_64                                  3.5.12-1.el7            @base    
libXpm-devel.x86_64                            3.5.12-1.el7            @base    
libXrandr.x86_64                               1.5.1-2.el7             @base    
libXrender.x86_64                              0.9.10-1.el7            @base    
libXt.x86_64                                   1.1.5-3.el7             @base    
libXt-devel.x86_64                             1.1.5-3.el7             @base    
libXtst.x86_64                                 1.2.3-1.el7             @base    
libXxf86misc.x86_64                            1.0.3-7.1.el7           @base    
libXxf86vm.x86_64                              1.1.4-1.el7             @base    
libacl.x86_64                                  2.2.51-15.el7           installed
libaio.x86_64                                  0.3.109-13.el7          @base    
libaio-devel.x86_64                            0.3.109-13.el7          @base    
libappindicator-gtk3.x86_64                    12.10.0-13.el7          @base    
libaps.x86_64                                  1.0.10-1centos.7.191108.1550
                                                                       @wp-toolkit-thirdparties
libarchive.x86_64                              3.1.2-14.el7_7          @base    
libart_lgpl.x86_64                             2.3.21-10.el7           @base    
libassuan.x86_64                               2.1.0-3.el7             installed
libattr.x86_64                                 2.4.46-13.el7           installed
libbasicobjects.x86_64                         0.1.1-32.el7            installed
libblkid.x86_64                                2.23.2-65.el7_9.1       @updates 
libblkid-devel.x86_64                          2.23.2-65.el7_9.1       @updates 
libc-client.x86_64                             2007f-16.el7            @epel    
libcap.x86_64                                  2.22-11.el7             installed
libcap-devel.x86_64                            2.22-11.el7             @base    
libcap-ng.x86_64                               0.7.5-4.el7             installed
libcgroup.x86_64                               0.41-21.el7             installed
libcollection.x86_64                           0.7.0-32.el7            installed
libcom_err.x86_64                              1.42.9-19.el7           @base    
libcom_err-devel.x86_64                        1.42.9-19.el7           @base    
libcroco.x86_64                                0.6.12-6.el7_9          @updates 
libcurl.x86_64                                 7.29.0-59.el7_9.1       @updates 
libcurl-devel.x86_64                           7.29.0-59.el7_9.1       @updates 
libdaemon.x86_64                               0.14-7.el7              installed
libdb.x86_64                                   5.3.21-25.el7           installed
libdb-devel.x86_64                             5.3.21-25.el7           @base    
libdb-utils.x86_64                             5.3.21-25.el7           installed
libdb4.x86_64                                  4.8.30-13.el7           @epel    
libdb4-cxx.x86_64                              4.8.30-13.el7           @epel    
libdb4-devel.x86_64                            4.8.30-13.el7           @epel    
libdbusmenu.x86_64                             16.04.0-4.el7           @base    
libdbusmenu-gtk3.x86_64                        16.04.0-4.el7           @base    
libdrm.x86_64                                  2.4.97-2.el7            @base    
libedit.x86_64                                 3.0-12.20121213cvs.el7  installed
libepoxy.x86_64                                1.5.2-1.el7             @base    
liberation-fonts.noarch                        1:1.07.2-16.el7         @base    
liberation-fonts-common.noarch                 1:1.07.2-16.el7         @base    
liberation-mono-fonts.noarch                   1:1.07.2-16.el7         @base    
liberation-narrow-fonts.noarch                 1:1.07.2-16.el7         @base    
liberation-sans-fonts.noarch                   1:1.07.2-16.el7         @base    
liberation-serif-fonts.noarch                  1:1.07.2-16.el7         @base    
libestr.x86_64                                 0.1.9-2.el7             installed
libevent.x86_64                                2.0.21-4.el7            installed
libevent-devel.x86_64                          2.0.21-4.el7            @base    
libfastjson.x86_64                             0.99.4-3.el7            installed
libffi.x86_64                                  3.0.13-19.el7           installed
libffi-devel.x86_64                            3.0.13-19.el7           @base    
libfontenc.x86_64                              1.1.3-3.el7             @base    
libgcc.x86_64                                  4.8.5-44.el7            @base    
libgcrypt.x86_64                               1.5.3-14.el7            installed
libgcrypt-devel.x86_64                         1.5.3-14.el7            @base    
libgfortran.x86_64                             4.8.5-44.el7            @base    
libglvnd.x86_64                                1:1.0.1-0.8.git5baa1e5.el7
                                                                       @base    
libglvnd-egl.x86_64                            1:1.0.1-0.8.git5baa1e5.el7
                                                                       @base    
libglvnd-glx.x86_64                            1:1.0.1-0.8.git5baa1e5.el7
                                                                       @base    
libgomp.x86_64                                 4.8.5-44.el7            @base    
libgpg-error.x86_64                            1.12-3.el7              installed
libgpg-error-devel.x86_64                      1.12-3.el7              @base    
libgs.x86_64                                   9.25-5.el7              @base    
libgs-devel.x86_64                             9.25-5.el7              @base    
libgsasl.x86_64                                1.8.0-8.el7             @epel    
libgsf.x86_64                                  1.14.26-7.el7           @base    
libgudev1.x86_64                               219-78.el7_9.5          @updates 
libgusb.x86_64                                 0.2.9-1.el7             @base    
libicu.x86_64                                  50.2-4.el7_7            @base    
libidn.x86_64                                  1.28-4.el7              installed
libidn-devel.x86_64                            1.28-4.el7              @base    
libidn2.x86_64                                 2.3.2-1.el7             @epel    
libindicator-gtk3.x86_64                       12.10.1-6.el7           @base    
libini_config.x86_64                           1.3.1-32.el7            installed
libjpeg-turbo.x86_64                           1.2.90-8.el7            @base    
libjpeg-turbo-devel.x86_64                     1.2.90-8.el7            @base    
libkadm5.x86_64                                1.15.1-51.el7_9         @updates 
liblockfile.x86_64                             1.08-17.el7             @base    
libmemcached.x86_64                            1.0.16-5.el7            @base    
libmnl.x86_64                                  1.0.3-7.el7             installed
libmodman.x86_64                               2.0.1-8.el7             @base    
libmount.x86_64                                2.23.2-65.el7_9.1       @updates 
libmount-devel.x86_64                          2.23.2-65.el7_9.1       @updates 
libmpc.x86_64                                  1.0.1-3.el7             @base    
libndp.x86_64                                  1.2-9.el7               installed
libnetfilter_conntrack.x86_64                  1.0.6-1.el7_3           installed
libnfnetlink.x86_64                            1.0.1-4.el7             installed
libnfsidmap.x86_64                             0.25-19.el7             installed
libnl.x86_64                                   1.1.4-3.el7             @base    
libnl3.x86_64                                  3.2.28-4.el7            installed
libnl3-cli.x86_64                              3.2.28-4.el7            installed
libntlm.x86_64                                 1.3-6.el7               @base    
libpaper.x86_64                                1.1.24-9.el7            @base    
libpath_utils.x86_64                           0.2.1-32.el7            installed
libpcap.x86_64                                 14:1.5.3-12.el7         @base    
libpcap-devel.x86_64                           14:1.5.3-12.el7         @base    
libpciaccess.x86_64                            0.14-1.el7              @base    
libpipeline.x86_64                             1.2.3-3.el7             installed
libpng.x86_64                                  2:1.5.13-8.el7          @base    
libpng-devel.x86_64                            2:1.5.13-8.el7          @base    
libproxy.x86_64                                0.4.11-11.el7           @base    
libpwquality.x86_64                            1.2.3-5.el7             installed
libquadmath.x86_64                             4.8.5-44.el7            @base    
libref_array.x86_64                            0.1.5-32.el7            installed
libreport-filesystem.x86_64                    2.1.11-53.el7.centos    @base    
librsvg2.x86_64                                2.40.20-1.el7           @base    
libseccomp.x86_64                              2.3.1-4.el7             installed
libselinux.x86_64                              2.5-15.el7              installed
libselinux-devel.x86_64                        2.5-15.el7              @base    
libselinux-python.x86_64                       2.5-15.el7              installed
libselinux-utils.x86_64                        2.5-15.el7              installed
libsemanage.x86_64                             2.5-14.el7              installed
libsemanage-python.x86_64                      2.5-14.el7              installed
libsepol.x86_64                                2.5-10.el7              installed
libsepol-devel.x86_64                          2.5-10.el7              @base    
libsmartcols.x86_64                            2.23.2-65.el7_9.1       @updates 
libsoup.x86_64                                 2.62.2-2.el7            @base    
libss.x86_64                                   1.42.9-19.el7           @base    
libssh2.x86_64                                 1.8.0-4.el7             @base    
libssh2-devel.x86_64                           1.8.0-4.el7             @base    
libstdc++.x86_64                               4.8.5-44.el7            @base    
libstdc++-devel.x86_64                         4.8.5-44.el7            @base    
libsysfs.x86_64                                2.1.0-16.el7            installed
libtasn1.x86_64                                4.10-1.el7              installed
libteam.x86_64                                 1.29-3.el7              @base    
libtermkey.x86_64                              0.20-4.el7              @epel    
libthai.x86_64                                 0.1.14-9.el7            @base    
libtiff.x86_64                                 4.0.3-35.el7            @base    
libtiff-devel.x86_64                           4.0.3-35.el7            @base    
libtirpc.x86_64                                0.2.4-0.16.el7          installed
libtool.x86_64                                 2.4.2-22.el7_3          @base    
libtool-ltdl.x86_64                            2.4.2-22.el7_3          @base    
libtool-ltdl-devel.x86_64                      2.4.2-22.el7_3          @base    
libunistring.x86_64                            0.9.3-9.el7             installed
libusb.x86_64                                  1:0.1.4-3.el7           @base    
libusbx.x86_64                                 1.0.21-1.el7            @base    
libuser.x86_64                                 0.60-9.el7              installed
libutempter.x86_64                             1.1.6-4.el7             installed
libuuid.x86_64                                 2.23.2-65.el7_9.1       @updates 
libuuid-devel.x86_64                           2.23.2-65.el7_9.1       @updates 
libuv.x86_64                                   1:1.43.0-2.el7          @epel    
libverto.x86_64                                0.2.5-4.el7             installed
libverto-devel.x86_64                          0.2.5-4.el7             @base    
libverto-libevent.x86_64                       0.2.5-4.el7             installed
libvpx.x86_64                                  1.3.0-8.el7             @base    
libvterm.x86_64                                0-0.2.bzr681.el7        @epel    
libwayland-client.x86_64                       1.15.0-1.el7            @base    
libwayland-cursor.x86_64                       1.15.0-1.el7            @base    
libwayland-egl.x86_64                          1.15.0-1.el7            @base    
libwayland-server.x86_64                       1.15.0-1.el7            @base    
libwebp.x86_64                                 0.3.0-10.el7_9          @updates 
libwmf.x86_64                                  0.2.8.4-44.el7          @base    
libwmf-lite.x86_64                             0.2.8.4-44.el7          @base    
libxcb.x86_64                                  1.13-1.el7              @base    
libxcb-devel.x86_64                            1.13-1.el7              @base    
libxkbcommon.x86_64                            0.7.1-3.el7             @base    
libxml2.x86_64                                 2.9.1-6.el7_9.6         @updates 
libxml2-devel.x86_64                           2.9.1-6.el7_9.6         @updates 
libxml2-python.x86_64                          2.9.1-6.el7_9.6         @updates 
libxshmfence.x86_64                            1.2-1.el7               @base    
libxslt.x86_64                                 1.1.28-6.el7            @base    
libxslt-devel.x86_64                           1.1.28-6.el7            @base    
libyaml.x86_64                                 0.1.4-11.el7_0          installed
libzip.x86_64                                  0.10.1-8.el7            @base    
libzip-devel.x86_64                            0.10.1-8.el7            @base    
libzstd.x86_64                                 1.5.1-4.el7             @epel    
linux-firmware.noarch                          20200421-80.git78c0348.el7_9
                                                                       @updates 
lksctp-tools.x86_64                            1.0.17-2.el7            @base    
lm_sensors-libs.x86_64                         3.4.0-8.20160601gitf9185e5.el7
                                                                       @base    
log4cplus.x86_64                               1.2.0.1-1centos.7.191108.1550
                                                                       @wp-toolkit-thirdparties
logrotate.x86_64                               3.8.6-19.el7            installed
lshw.x86_64                                    B.02.18-17.el7          @base    
lsof.x86_64                                    4.87-6.el7              @base    
lsscsi.x86_64                                  0.27-6.el7              @base    
ltrace.x86_64                                  0.7.91-16.el7           @base    
lua.x86_64                                     5.1.4-15.el7            installed
lua-bit32.x86_64                               5.3.0-2.el7             @epel    
lua-devel.x86_64                               5.1.4-15.el7            @base    
lvm2.x86_64                                    7:2.02.187-6.el7_9.5    @updates 
lvm2-libs.x86_64                               7:2.02.187-6.el7_9.5    @updates 
lynx.x86_64                                    2.8.8-0.3.dev15.el7     @base    
lz4.x86_64                                     1.8.3-1.el7             @base    
lzo.x86_64                                     2.06-8.el7              installed
m2crypto.x86_64                                0.21.1-17.el7           @base    
m4.x86_64                                      1.4.16-10.el7           @base    
mailcap.noarch                                 2.1.41-2.el7            @base    
mailx.x86_64                                   12.5-19.el7             @base    
make.x86_64                                    1:3.82-24.el7           installed
man-db.x86_64                                  2.6.3-11.el7            installed
mdadm.x86_64                                   4.1-8.el7_9             @updates 
memcached.x86_64                               1.4.15-10.el7_3.1       @base    
mesa-libEGL.x86_64                             18.3.4-12.el7_9         @updates 
mesa-libGL.x86_64                              18.3.4-12.el7_9         @updates 
mesa-libgbm.x86_64                             18.3.4-12.el7_9         @updates 
mesa-libglapi.x86_64                           18.3.4-12.el7_9         @updates 
microcode_ctl.x86_64                           2:2.1-73.11.el7_9       @updates 
mlocate.x86_64                                 0.26-8.el7              @base    
mozjs17.x86_64                                 17.0.0-20.el7           installed
mpfr.x86_64                                    3.1.1-4.el7             @base    
msgpack.x86_64                                 3.1.0-4.el7             @epel    
mtr.x86_64                                     2:0.85-7.el7            @base    
mysql-community-client.x86_64                  5.7.37-1.el7            @Mysql57-community
mysql-community-common.x86_64                  5.7.37-1.el7            @Mysql57-community
mysql-community-devel.x86_64                   5.7.37-1.el7            @Mysql57-community
mysql-community-libs.x86_64                    5.7.37-1.el7            @Mysql57-community
mysql-community-libs-compat.x86_64             5.7.37-1.el7            @Mysql57-community
mysql-community-server.x86_64                  5.7.37-1.el7            @Mysql57-community
nano.x86_64                                    2.3.1-10.el7            @base    
ncurses.x86_64                                 5.9-14.20130511.el7_4   installed
ncurses-base.noarch                            5.9-14.20130511.el7_4   installed
ncurses-devel.x86_64                           5.9-14.20130511.el7_4   @base    
ncurses-libs.x86_64                            5.9-14.20130511.el7_4   installed
ncurses-term.noarch                            5.9-14.20130511.el7_4   @base    
neovim.x86_64                                  0.3.0-2.el7             @epel    
net-snmp-libs.x86_64                           1:5.7.2-49.el7_9.1      @updates 
net-tools.x86_64                               2.0-0.25.20131004git.el7
                                                                       installed
nettle.x86_64                                  2.7.1-9.el7_9           @updates 
newt.x86_64                                    0.52.15-4.el7           installed
newt-python.x86_64                             0.52.15-4.el7           installed
nfs-utils.x86_64                               1:1.3.0-0.68.el7.2      @updates 
nmap.x86_64                                    2:6.40-19.el7           @base    
nmap-ncat.x86_64                               2:6.40-19.el7           @base    
nscd.x86_64                                    2.17-325.el7_9          @updates 
nspr.x86_64                                    4.32.0-1.el7_9          @updates 
nss.x86_64                                     3.67.0-4.el7_9          @updates 
nss-pem.x86_64                                 1.0.3-7.el7             installed
nss-softokn.x86_64                             3.67.0-3.el7_9          @updates 
nss-softokn-freebl.x86_64                      3.67.0-3.el7_9          @updates 
nss-sysinit.x86_64                             3.67.0-4.el7_9          @updates 
nss-tools.x86_64                               3.67.0-4.el7_9          @updates 
nss-util.x86_64                                3.67.0-1.el7_9          @updates 
nss_compat_ossl.x86_64                         0.9.6-8.el7             @base    
ntp.x86_64                                     4.2.6p5-29.el7.centos.2 @base    
ntpdate.x86_64                                 4.2.6p5-29.el7.centos.2 @base    
numactl-libs.x86_64                            2.0.12-5.el7            installed
numpy.x86_64                                   1:1.7.1-13.el7          @base    
openjpeg-libs.x86_64                           1.5.1-18.el7            @base    
openjpeg2.x86_64                               2.3.1-3.el7_7           @base    
openldap.x86_64                                2.4.44-24.el7_9         @updates 
openldap-devel.x86_64                          2.4.44-24.el7_9         @updates 
openssh.x86_64                                 7.4p1-22.el7_9          @updates 
openssh-clients.x86_64                         7.4p1-22.el7_9          @updates 
openssh-server.x86_64                          7.4p1-22.el7_9          @updates 
openssl.x86_64                                 1:1.0.2k-24.el7_9       @updates 
openssl-devel.x86_64                           1:1.0.2k-24.el7_9       @updates 
openssl-libs.x86_64                            1:1.0.2k-24.el7_9       @updates 
os-prober.x86_64                               1.58-9.el7              installed
p11-kit.x86_64                                 0.23.5-3.el7            installed
p11-kit-trust.x86_64                           0.23.5-3.el7            installed
pam.x86_64                                     1.1.8-23.el7            installed
pam-devel.x86_64                               1.1.8-23.el7            @base    
pango.x86_64                                   1.42.4-4.el7_7          @base    
parted.x86_64                                  3.1-32.el7              installed
passwd.x86_64                                  0.79-6.el7              installed
patch.x86_64                                   2.7.1-12.el7_7          @base    
pciutils-libs.x86_64                           3.5.1-3.el7             installed
pcre.x86_64                                    8.32-17.el7             installed
pcre-devel.x86_64                              8.32-17.el7             @base    
pcre2.x86_64                                   10.23-2.el7             @base    
pcre2-devel.x86_64                             10.23-2.el7             @base    
pcre2-utf16.x86_64                             10.23-2.el7             @base    
pcre2-utf32.x86_64                             10.23-2.el7             @base    
pcsc-lite-libs.x86_64                          1.8.8-8.el7             @base    
perl.x86_64                                    4:5.16.3-299.el7_9      @updates 
perl-Archive-Extract.noarch                    1:0.68-3.el7            @base    
perl-Archive-Tar.noarch                        1.92-3.el7              @base    
perl-Archive-Zip.noarch                        1.30-11.el7             @base    
perl-Authen-SASL.noarch                        2.15-10.el7             @base    
perl-B-Lint.noarch                             1.17-3.el7              @base    
perl-Bit-Vector.x86_64                         7.3-3.el7               @base    
perl-Business-ISBN.noarch                      2.06-2.el7              @base    
perl-Business-ISBN-Data.noarch                 20120719.001-2.el7      @base    
perl-CGI.noarch                                3.63-4.el7              @base    
perl-CPAN.noarch                               1.9800-299.el7_9        @updates 
perl-CPAN-Meta.noarch                          2.120921-5.el7          @base    
perl-CPAN-Meta-Requirements.noarch             2.122-7.el7             @base    
perl-CPAN-Meta-YAML.noarch                     0.008-14.el7            @base    
perl-CPANPLUS.noarch                           0.91.38-4.el7           @base    
perl-CPANPLUS-Dist-Build.noarch                0.70-3.el7              @base    
perl-Carp.noarch                               1.26-244.el7            @base    
perl-Carp-Clan.noarch                          6.04-10.el7             @base    
perl-Compress-Raw-Bzip2.x86_64                 2.061-3.el7             @base    
perl-Compress-Raw-Zlib.x86_64                  1:2.061-4.el7           @base    
perl-Config-Tiny.noarch                        2.14-7.el7              @base    
perl-Convert-ASN1.noarch                       0.26-4.el7              @base    
perl-DBD-SQLite.x86_64                         1.39-3.el7              @base    
perl-DBI.x86_64                                1.627-4.el7             @base    
perl-DBIx-Simple.noarch                        1.35-7.el7              @base    
perl-DB_File.x86_64                            1.830-6.el7             @base    
perl-Data-Dumper.x86_64                        2.145-3.el7             @base    
perl-Digest.noarch                             1.17-245.el7            @base    
perl-Digest-HMAC.noarch                        1.03-5.el7              @base    
perl-Digest-MD5.x86_64                         2.52-3.el7              @base    
perl-Digest-SHA.x86_64                         1:5.85-4.el7            @base    
perl-Digest-SHA1.x86_64                        2.13-9.el7              @base    
perl-Digest-SHA3.x86_64                        0.24-1.el7              @epel    
perl-Email-Date-Format.noarch                  1.002-15.el7            @epel    
perl-Encode.x86_64                             2.51-7.el7              @base    
perl-Encode-Locale.noarch                      1.03-5.el7              @base    
perl-Env.noarch                                1.04-2.el7              @base    
perl-Error.noarch                              1:0.17020-2.el7         @base    
perl-Expect.noarch                             1.21-14.el7             @epel    
perl-Exporter.noarch                           5.68-3.el7              @base    
perl-ExtUtils-CBuilder.noarch                  1:0.28.2.6-299.el7_9    @updates 
perl-ExtUtils-Embed.noarch                     1.30-299.el7_9          @updates 
perl-ExtUtils-Install.noarch                   1.58-299.el7_9          @updates 
perl-ExtUtils-MakeMaker.noarch                 6.68-3.el7              @base    
perl-ExtUtils-Manifest.noarch                  1.61-244.el7            @base    
perl-ExtUtils-ParseXS.noarch                   1:3.18-3.el7            @base    
perl-FCGI.x86_64                               1:0.74-8.el7            @base    
perl-File-BaseDir.noarch                       0.03-14.el7             @epel    
perl-File-CheckTree.noarch                     4.42-3.el7              @base    
perl-File-Copy-Recursive.noarch                0.38-14.el7             @base    
perl-File-DesktopEntry.noarch                  0.08-1.el7              @epel    
perl-File-Fetch.noarch                         0.42-2.el7              @base    
perl-File-Listing.noarch                       6.04-7.el7              @base    
perl-File-Next.noarch                          1.16-1.el7              @epel    
perl-File-Path.noarch                          2.09-2.el7              @base    
perl-File-Temp.noarch                          0.23.01-3.el7           @base    
perl-Filter.x86_64                             1.49-3.el7              @base    
perl-GSSAPI.x86_64                             0.28-9.el7              @base    
perl-Getopt-Long.noarch                        2.40-3.el7              @base    
perl-Git.noarch                                1.8.3.1-23.el7_8        @base    
perl-HTML-Parser.x86_64                        3.71-4.el7              @base    
perl-HTML-Tagset.noarch                        3.20-15.el7             @base    
perl-HTTP-Cookies.noarch                       6.01-5.el7              @base    
perl-HTTP-Daemon.noarch                        6.01-8.el7              @base    
perl-HTTP-Date.noarch                          6.02-8.el7              @base    
perl-HTTP-Message.noarch                       6.06-6.el7              @base    
perl-HTTP-Negotiate.noarch                     6.01-5.el7              @base    
perl-HTTP-Tiny.noarch                          0.033-3.el7             @base    
perl-IO-Compress.noarch                        2.061-2.el7             @base    
perl-IO-HTML.noarch                            1.00-2.el7              @base    
perl-IO-Socket-IP.noarch                       0.21-5.el7              @base    
perl-IO-Socket-SSL.noarch                      1.94-7.el7              @base    
perl-IO-Tty.x86_64                             1.10-11.el7             @base    
perl-IO-Zlib.noarch                            1:1.10-299.el7_9        @updates 
perl-IPC-Cmd.noarch                            1:0.80-4.el7            @base    
perl-JSON.noarch                               2.59-2.el7              @base    
perl-JSON-PP.noarch                            2.27202-2.el7           @base    
perl-JSON-XS.x86_64                            1:3.01-2.el7            @epel    
perl-LDAP.noarch                               1:0.56-6.el7            @base    
perl-LWP-MediaTypes.noarch                     6.02-2.el7              @base    
perl-List-MoreUtils.x86_64                     0.33-9.el7              @base    
perl-Locale-Codes.noarch                       3.26-2.el7              @base    
perl-Locale-Maketext.noarch                    1.23-3.el7              @base    
perl-Locale-Maketext-Simple.noarch             1:0.21-299.el7_9        @updates 
perl-Log-Message.noarch                        1:0.08-3.el7            @base    
perl-Log-Message-Simple.noarch                 0.10-2.el7              @base    
perl-MIME-Lite.noarch                          3.030-1.el7             @epel    
perl-MIME-Types.noarch                         1.38-2.el7              @epel    
perl-Module-Build.noarch                       2:0.40.05-2.el7         @base    
perl-Module-CoreList.noarch                    1:2.76.02-299.el7_9     @updates 
perl-Module-Load.noarch                        1:0.24-3.el7            @base    
perl-Module-Load-Conditional.noarch            0.54-3.el7              @base    
perl-Module-Loaded.noarch                      1:0.08-299.el7_9        @updates 
perl-Module-Metadata.noarch                    1.000018-2.el7          @base    
perl-Module-Pluggable.noarch                   1:4.8-3.el7             @base    
perl-Mozilla-CA.noarch                         20130114-5.el7          @base    
perl-Net-Daemon.noarch                         0.48-5.el7              @base    
perl-Net-HTTP.noarch                           6.06-2.el7              @base    
perl-Net-LibIDN.x86_64                         0.12-15.el7             @base    
perl-Net-SSLeay.x86_64                         1.55-6.el7              @base    
perl-Object-Accessor.noarch                    1:0.42-299.el7_9        @updates 
perl-Package-Constants.noarch                  1:0.02-299.el7_9        @updates 
perl-Params-Check.noarch                       1:0.38-2.el7            @base    
perl-Parse-CPAN-Meta.noarch                    1:1.4404-5.el7          @base    
perl-PathTools.x86_64                          3.40-5.el7              @base    
perl-Perl-OSType.noarch                        1.003-3.el7             @base    
perl-PlRPC.noarch                              0.2020-14.el7           @base    
perl-Pod-Checker.noarch                        1.60-2.el7              @base    
perl-Pod-Escapes.noarch                        1:1.04-299.el7_9        @updates 
perl-Pod-LaTeX.noarch                          0.61-2.el7              @base    
perl-Pod-Parser.noarch                         1.61-2.el7              @base    
perl-Pod-Perldoc.noarch                        3.20-4.el7              @base    
perl-Pod-Simple.noarch                         1:3.28-4.el7            @base    
perl-Pod-Usage.noarch                          1.63-3.el7              @base    
perl-Scalar-List-Utils.x86_64                  1.27-248.el7            @base    
perl-Socket.x86_64                             2.010-5.el7             @base    
perl-Storable.x86_64                           2.45-3.el7              @base    
perl-Switch.noarch                             2.16-7.el7              @base    
perl-Sys-Syslog.x86_64                         0.33-3.el7              @base    
perl-Term-UI.noarch                            0.36-2.el7              @base    
perl-TermReadKey.x86_64                        2.30-20.el7             @base    
perl-Test-Harness.noarch                       3.28-3.el7              @base    
perl-Test-Simple.noarch                        0.98-243.el7            @base    
perl-Text-ParseWords.noarch                    3.29-4.el7              @base    
perl-Text-Soundex.x86_64                       3.04-4.el7              @base    
perl-Text-Unidecode.noarch                     0.04-20.el7             @base    
perl-Thread-Queue.noarch                       3.02-2.el7              @base    
perl-Time-HiRes.x86_64                         4:1.9725-3.el7          @base    
perl-Time-Local.noarch                         1.2300-2.el7            @base    
perl-Time-Piece.x86_64                         1.20.1-299.el7_9        @updates 
perl-TimeDate.noarch                           1:2.30-2.el7            @base    
perl-Try-Tiny.noarch                           0.12-2.el7              @base    
perl-Types-Serialiser.noarch                   1.0-1.el7               @epel    
perl-URI.noarch                                1.60-9.el7              @base    
perl-Version-Requirements.noarch               0.101022-244.el7        @base    
perl-WWW-RobotRules.noarch                     6.02-5.el7              @base    
perl-XML-Filter-BufferText.noarch              1.01-17.el7             @base    
perl-XML-NamespaceSupport.noarch               1.11-10.el7             @base    
perl-XML-Parser.x86_64                         2.41-10.el7             @base    
perl-XML-SAX-Base.noarch                       1.08-7.el7              @base    
perl-XML-SAX-Writer.noarch                     0.53-4.el7              @base    
perl-YAML-LibYAML.x86_64                       0.54-1.el7              @epel    
perl-YAML-Syck.x86_64                          1.27-3.el7              @base    
perl-autodie.noarch                            2.16-2.el7              @base    
perl-common-sense.noarch                       3.6-4.el7               @epel    
perl-constant.noarch                           1.27-2.el7              @base    
perl-core.x86_64                               5.16.3-299.el7_9        @updates 
perl-devel.x86_64                              4:5.16.3-299.el7_9      @updates 
perl-libintl.x86_64                            1.20-12.el7             @base    
perl-libs.x86_64                               4:5.16.3-299.el7_9      @updates 
perl-libwww-perl.noarch                        6.05-2.el7              @base    
perl-local-lib.noarch                          1.008010-4.el7          @base    
perl-macros.x86_64                             4:5.16.3-299.el7_9      @updates 
perl-parent.noarch                             1:0.225-244.el7         @base    
perl-podlators.noarch                          2.5.1-3.el7             @base    
perl-srpm-macros.noarch                        1-8.el7                 @base    
perl-threads.x86_64                            1.87-4.el7              @base    
perl-threads-shared.x86_64                     1.43-6.el7              @base    
perl-version.x86_64                            3:0.99.07-6.el7         @base    
pinentry.x86_64                                0.8.1-17.el7            installed
pixman.x86_64                                  0.34.0-1.el7            @base    
pkgconfig.x86_64                               1:0.27.1-4.el7          installed
plesk-libboost-1.65.x86_64                     1.65.1-1centos.7.190116.1809
                                                                       @wp-toolkit-thirdparties
plesk-libboost-date-time1.65.x86_64            1.65.1-1centos.7.190116.1809
                                                                       @wp-toolkit-thirdparties
plesk-libboost-filesystem1.65.x86_64           1.65.1-1centos.7.190116.1809
                                                                       @wp-toolkit-thirdparties
plesk-libboost-program-options1.65.x86_64      1.65.1-1centos.7.190116.1809
                                                                       @wp-toolkit-thirdparties
plesk-libboost-regex1.65.x86_64                1.65.1-1centos.7.190116.1809
                                                                       @wp-toolkit-thirdparties
plesk-libboost-serialization1.65.x86_64        1.65.1-1centos.7.190116.1809
                                                                       @wp-toolkit-thirdparties
plesk-libboost-system1.65.x86_64               1.65.1-1centos.7.190116.1809
                                                                       @wp-toolkit-thirdparties
plesk-libboost-thread1.65.x86_64               1.65.1-1centos.7.190116.1809
                                                                       @wp-toolkit-thirdparties
plesk-libpoco-1.9.0.x86_64                     1.9.0-1centos.7.191202.1336
                                                                       @wp-toolkit-thirdparties
plesk-libstdc++6.3.0.x86_64                    6.3.0-1centos.7.190110.1553
                                                                       @wp-toolkit-thirdparties
plesk-lmlib.x86_64                             0.2.4-1centos.7.191108.1550
                                                                       @wp-toolkit-thirdparties
plesk-platform-runtime.x86_64                  1.0.2-1centos.7.191108.1550
                                                                       @wp-toolkit-thirdparties
plesk-rdbmspp.x86_64                           2.0.2-1centos.7.191108.1550
                                                                       @wp-toolkit-thirdparties
plymouth.x86_64                                0.8.9-0.34.20140113.el7.centos
                                                                       @base    
plymouth-core-libs.x86_64                      0.8.9-0.34.20140113.el7.centos
                                                                       @base    
plymouth-scripts.x86_64                        0.8.9-0.34.20140113.el7.centos
                                                                       @base    
policycoreutils.x86_64                         2.5-34.el7              installed
policycoreutils-python.x86_64                  2.5-34.el7              installed
polkit.x86_64                                  0.112-26.el7_9.1        @updates 
polkit-pkla-compat.x86_64                      0.1-4.el7               installed
poppler.x86_64                                 0.26.5-43.el7.1         @updates 
poppler-data.noarch                            0.4.6-3.el7             @base    
popt.x86_64                                    1.13-16.el7             installed
postgresql.x86_64                              9.2.24-7.el7_9          @updates 
postgresql-devel.x86_64                        9.2.24-7.el7_9          @updates 
postgresql-libs.x86_64                         9.2.24-7.el7_9          @updates 
postgresql-server.x86_64                       9.2.24-7.el7_9          @updates 
procps-ng.x86_64                               3.3.10-28.el7           @base    
protobuf.x86_64                                2.5.0-8.el7             @base    
protobuf-compiler.x86_64                       2.5.0-8.el7             @base    
protobuf-devel.x86_64                          2.5.0-8.el7             @base    
psmisc.x86_64                                  22.20-17.el7            @base    
psutils.x86_64                                 1.17-44.el7             @base    
psutils-perl.noarch                            1.17-44.el7             @base    
pth.x86_64                                     2.0.7-23.el7            installed
pxz.x86_64                                     4.999.9-19.beta.20200421git.el7
                                                                       @epel    
pyOpenSSL.x86_64                               0.13.1-4.el7            @base    
pycairo.x86_64                                 1.8.10-8.el7            @base    
pygobject2.x86_64                              2.28.6-11.el7           @base    
pygpgme.x86_64                                 0.3-9.el7               installed
pygtk2.x86_64                                  2.24.0-9.el7            @base    
pyliblzma.x86_64                               0.5.3-11.el7            installed
pyparsing.noarch                               1.5.6-9.el7             @base    
pyserial.noarch                                2.6-6.el7               installed
python.x86_64                                  2.7.5-90.el7            @updates 
python-IPy.noarch                              0.75-6.el7              installed
python-babel.noarch                            0.9.6-8.el7             installed
python-backports.x86_64                        1.0-8.el7               installed
python-backports-ssl_match_hostname.noarch     3.5.0.1-1.el7           installed
python-chardet.noarch                          2.2.1-3.el7             installed
python-cheetah.x86_64                          2.4.4-5.el7.centos      @extras  
python-clufter.noarch                          0.77.1-1.el7            @base    
python-configobj.noarch                        4.7.2-7.el7             installed
python-dateutil.noarch                         1.5-7.el7               @base    
python-decorator.noarch                        3.4.0-3.el7             installed
python-devel.x86_64                            2.7.5-90.el7            @updates 
python-dmidecode.x86_64                        3.12.2-4.el7            @base    
python-docs.noarch                             2.7.5-3.el7             @base    
python-ethtool.x86_64                          0.8-8.el7               @base    
python-firewall.noarch                         0.6.3-13.el7_9          @updates 
python-gobject-base.x86_64                     3.22.0-1.el7_4.1        installed
python-gudev.x86_64                            147.2-7.el7             @base    
python-hwdata.noarch                           1.7.3-4.el7             @base    
python-iniparse.noarch                         0.4-9.el7               installed
python-ipaddress.noarch                        1.0.16-2.el7            installed
python-javapackages.noarch                     3.4.1-11.el7            @base    
python-jinja2.noarch                           2.7.2-4.el7             installed
python-jsonpatch.noarch                        1.2-4.el7               installed
python-jsonpointer.noarch                      1.9-2.el7               installed
python-kitchen.noarch                          1.1.1-5.el7             installed
python-libs.x86_64                             2.7.5-90.el7            @updates 
python-linux-procfs.noarch                     0.4.11-4.el7            installed
python-lxml.x86_64                             3.2.1-4.el7             @base    
python-markupsafe.x86_64                       0.11-10.el7             installed
python-matplotlib.x86_64                       1.2.0-16.el7            @base    
python-nose.noarch                             1.3.7-1.el7             @base    
python-oauth.noarch                            1.0.1-10.el7            @epel    
python-perf.x86_64                             3.10.0-1160.53.1.el7    @updates 
python-pillow.x86_64                           2.0.0-21.gitd1c6db8.el7 @base    
python-ply.noarch                              3.4-11.el7              @base    
python-prettytable.noarch                      0.7.2-3.el7             installed
python-pycurl.x86_64                           7.19.0-19.el7           installed
python-pygments.noarch                         1.4-10.el7              @base    
python-pyudev.noarch                           0.15-9.el7              installed
python-requests.noarch                         2.6.0-10.el7            @base    
python-rpm-macros.noarch                       3-34.el7                @base    
python-schedutils.x86_64                       0.4-6.el7               installed
python-setuptools.noarch                       0.9.8-7.el7             installed
python-six.noarch                              1.9.0-2.el7             installed
python-slip.noarch                             0.4.0-4.el7             @base    
python-slip-dbus.noarch                        0.4.0-4.el7             @base    
python-srpm-macros.noarch                      3-34.el7                @base    
python-tools.x86_64                            2.7.5-90.el7            @updates 
python-urlgrabber.noarch                       3.10-10.el7             installed
python-urllib3.noarch                          1.10.2-7.el7            installed
python2-markdown.noarch                        2.4.1-4.el7             @epel    
python2-root.x86_64                            6.24.06-2.el7           @epel    
python2-rpm-macros.noarch                      3-34.el7                @base    
python2-simplejson.x86_64                      3.11.1-1.el7            @epel    
python3.x86_64                                 3.6.8-18.el7            @updates 
python3-libs.x86_64                            3.6.8-18.el7            @updates 
python3-pip.noarch                             9.0.3-8.el7             @base    
python3-setuptools.noarch                      39.2.0-10.el7           @base    
python36-root.x86_64                           6.24.06-2.el7           @epel    
pytz.noarch                                    2016.10-2.el7           @base    
pyxattr.x86_64                                 0.5.1-5.el7             installed
qemu-guest-agent.x86_64                        10:2.12.0-3.el7         installed
qrencode-libs.x86_64                           3.4.1-3.el7             installed
quota.x86_64                                   1:4.01-19.el7           installed
quota-devel.x86_64                             1:4.01-19.el7           @base    
quota-nls.noarch                               1:4.01-19.el7           installed
rcs.x86_64                                     5.9.0-7.el7             @base    
rdate.x86_64                                   1.4-25.el7              @base    
readline.x86_64                                6.2-11.el7              installed
readline-devel.x86_64                          6.2-11.el7              @base    
redhat-lsb-core.x86_64                         4.1-27.el7.centos.1     @base    
redhat-lsb-submod-security.x86_64              4.1-27.el7.centos.1     @base    
redhat-rpm-config.noarch                       9.1.0-88.el7.centos     @base    
rest.x86_64                                    0.8.1-2.el7             @base    
rhash.x86_64                                   1.3.4-2.el7             @epel    
rhn-check.x86_64                               2.0.2-24.el7            @base    
rhn-client-tools.x86_64                        2.0.2-24.el7            @base    
rhn-setup.x86_64                               2.0.2-24.el7            @base    
rhnlib.noarch                                  2.5.65-8.el7            @base    
rhnsd.x86_64                                   5.0.13-10.el7           @base    
rng-tools.x86_64                               6.3.1-5.el7             @base    
root-cli.noarch                                6.24.06-2.el7           @epel    
root-cling.x86_64                              6.24.06-2.el7           @epel    
root-core.x86_64                               6.24.06-2.el7           @epel    
root-fonts.noarch                              6.24.06-2.el7           @epel    
root-graf.x86_64                               6.24.06-2.el7           @epel    
root-graf-asimage.x86_64                       6.24.06-2.el7           @epel    
root-graf-gpad.x86_64                          6.24.06-2.el7           @epel    
root-graf-postscript.x86_64                    6.24.06-2.el7           @epel    
root-graf-x11.x86_64                           6.24.06-2.el7           @epel    
root-graf3d.x86_64                             6.24.06-2.el7           @epel    
root-gui.x86_64                                6.24.06-2.el7           @epel    
root-gui-ged.x86_64                            6.24.06-2.el7           @epel    
root-hist.x86_64                               6.24.06-2.el7           @epel    
root-hist-painter.x86_64                       6.24.06-2.el7           @epel    
root-icons.noarch                              6.24.06-2.el7           @epel    
root-io.x86_64                                 6.24.06-2.el7           @epel    
root-mathcore.x86_64                           6.24.06-2.el7           @epel    
root-mathmore.x86_64                           6.24.06-2.el7           @epel    
root-matrix.x86_64                             6.24.06-2.el7           @epel    
root-minuit.x86_64                             6.24.06-2.el7           @epel    
root-multiproc.x86_64                          6.24.06-2.el7           @epel    
root-net.x86_64                                6.24.06-2.el7           @epel    
root-physics.x86_64                            6.24.06-2.el7           @epel    
root-tree.x86_64                               6.24.06-2.el7           @epel    
root-tree-dataframe.x86_64                     6.24.06-2.el7           @epel    
root-tree-player.x86_64                        6.24.06-2.el7           @epel    
root-vecops.x86_64                             6.24.06-2.el7           @epel    
rootfiles.noarch                               8.1-11.el7              installed
rpcbind.x86_64                                 0.2.0-49.el7            installed
rpm.x86_64                                     4.11.3-48.el7_9         @updates 
rpm-build.x86_64                               4.11.3-48.el7_9         @updates 
rpm-build-libs.x86_64                          4.11.3-48.el7_9         @updates 
rpm-libs.x86_64                                4.11.3-48.el7_9         @updates 
rpm-python.x86_64                              4.11.3-48.el7_9         @updates 
rpmlint.noarch                                 1.5-4.el7               @base    
rsync.x86_64                                   3.1.2-10.el7            installed
rsyslog.x86_64                                 8.24.0-57.el7_9.1       @updates 
ruby.x86_64                                    2.0.0.648-36.el7        @base    
ruby-irb.noarch                                2.0.0.648-36.el7        @base    
ruby-libs.x86_64                               2.0.0.648-36.el7        @base    
rubygem-bigdecimal.x86_64                      1.2.0-36.el7            @base    
rubygem-io-console.x86_64                      0.4.2-36.el7            @base    
rubygem-json.x86_64                            1.7.7-36.el7            @base    
rubygem-psych.x86_64                           2.0.0-36.el7            @base    
rubygem-rdoc.noarch                            4.0.0-36.el7            @base    
rubygems.noarch                                2.0.14.1-36.el7         @base    
scl-utils.x86_64                               20130529-19.el7         @base    
scl-utils-build.x86_64                         20130529-19.el7         @base    
screen.x86_64                                  4.1.0-0.27.20120314git3c2946.el7_9
                                                                       @updates 
sed.x86_64                                     4.2.2-7.el7             @base    
selinux-policy.noarch                          3.13.1-268.el7_9.2      @updates 
selinux-policy-targeted.noarch                 3.13.1-268.el7_9.2      @updates 
sensible-utils.noarch                          0.0.12-2.el7            @epel    
setools-libs.x86_64                            3.3.8-4.el7             installed
setup.noarch                                   2.8.71-11.el7           installed
sg3_utils.x86_64                               1:1.37-19.el7           installed
sg3_utils-libs.x86_64                          1:1.37-19.el7           installed
sgml-common.noarch                             0.6.3-39.el7            @base    
shadow-utils.x86_64                            2:4.6-5.el7             installed
shared-mime-info.x86_64                        1.8-5.el7               installed
sharutils.x86_64                               4.13.3-8.el7            @base    
slang.x86_64                                   2.2.4-11.el7            installed
smartmontools.x86_64                           1:7.0-2.el7             @base    
snappy.x86_64                                  1.1.0-3.el7             installed
source-highlight.x86_64                        3.1.6-6.el7             @base    
spax.x86_64                                    1.5.2-13.el7            @base    
sqlite.x86_64                                  3.7.17-8.el7_7.1        installed
sqlite-devel.x86_64                            3.7.17-8.el7_7.1        @base    
stix-fonts.noarch                              1.1.0-5.el7             @base    
stix-math-fonts.noarch                         1.1.0-5.el7             @base    
strace.x86_64                                  4.24-6.el7              @base    
stunnel.x86_64                                 4.56-6.el7              @base    
sudo.x86_64                                    1.8.23-10.el7_9.2       @updates 
sw-engine.x86_64                               2.27.2-1centos.7.191108.1550
                                                                       @wp-toolkit-thirdparties
sysstat.x86_64                                 10.1.5-19.el7           @base    
system-config-firewall-base.noarch             1.2.29-10.el7           @base    
systemd.x86_64                                 219-78.el7_9.5          @updates 
systemd-devel.x86_64                           219-78.el7_9.5          @updates 
systemd-libs.x86_64                            219-78.el7_9.5          @updates 
systemd-sysv.x86_64                            219-78.el7_9.5          @updates 
systemtap-sdt-devel.x86_64                     4.0-13.el7              @base    
sysvinit-tools.x86_64                          2.88-14.dsf.el7         installed
t1lib.x86_64                                   5.1.2-14.el7            @base    
tar.x86_64                                     2:1.26-35.el7           installed
tcl.x86_64                                     1:8.5.13-8.el7          @base    
tclx.x86_64                                    8.4.0-22.el7            @base    
tcp_wrappers.x86_64                            7.6-77.el7              installed
tcp_wrappers-devel.x86_64                      7.6-77.el7              @base    
tcp_wrappers-libs.x86_64                       7.6-77.el7              installed
tcpdump.x86_64                                 14:4.9.2-4.el7_7.1      @base    
teamd.x86_64                                   1.29-3.el7              @base    
telnet.x86_64                                  1:0.17-66.el7           @updates 
texinfo.x86_64                                 5.1-5.el7               @base    
texinfo-tex.x86_64                             5.1-5.el7               @base    
texlive-algorithms.noarch                      2:svn15878.0.1-45.el7   @base    
texlive-amsfonts.noarch                        2:svn29208.3.04-45.el7  @base    
texlive-amsmath.noarch                         2:svn29327.2.14-45.el7  @base    
texlive-attachfile.noarch                      2:svn21866.v1.5b-45.el7 @base    
texlive-avantgar.noarch                        2:svn28614.0-45.el7     @base    
texlive-babel.noarch                           2:svn24756.3.8m-45.el7  @base    
texlive-babelbib.noarch                        2:svn25245.1.31-45.el7  @base    
texlive-base.noarch                            2:2012-45.20130427_r30134.el7
                                                                       @base    
texlive-bera.noarch                            2:svn20031.0-45.el7     @base    
texlive-bibtex.noarch                          2:svn26689.0.99d-45.el7 @base    
texlive-bibtex-bin.x86_64                      2:svn26509.0-45.20130427_r30134.el7
                                                                       @base    
texlive-bookman.noarch                         2:svn28614.0-45.el7     @base    
texlive-booktabs.noarch                        2:svn15878.1.61803-45.el7
                                                                       @base    
texlive-breakurl.noarch                        2:svn15878.1.30-45.el7  @base    
texlive-caption.noarch                         2:svn29026.3.3__2013_02_03_-45.el7
                                                                       @base    
texlive-carlisle.noarch                        2:svn18258.0-45.el7     @base    
texlive-charter.noarch                         2:svn15878.0-45.el7     @base    
texlive-chngcntr.noarch                        2:svn17157.1.0a-45.el7  @base    
texlive-cm.noarch                              2:svn29581.0-45.el7     @base    
texlive-cm-super.noarch                        2:svn15878.0-45.el7     @base    
texlive-cmextra.noarch                         2:svn14075.0-45.el7     @base    
texlive-collection-basic.noarch                2:svn26314.0-45.20130427_r30134.el7
                                                                       @base    
texlive-collection-documentation-base.noarch   2:svn17091.0-45.20130427_r30134.el7
                                                                       @base    
texlive-collection-fontsrecommended.noarch     2:svn28082.0-45.20130427_r30134.el7
                                                                       @base    
texlive-colortbl.noarch                        2:svn25394.v1.0a-45.el7 @base    
texlive-courier.noarch                         2:svn28614.0-45.el7     @base    
texlive-csquotes.noarch                        2:svn24393.5.1d-45.el7  @base    
texlive-currfile.noarch                        2:svn29012.0.7b-45.el7  @base    
texlive-dvipdfm.noarch                         2:svn26689.0.13.2d-45.el7
                                                                       @base    
texlive-dvipdfm-bin.noarch                     2:svn13663.0-45.20130427_r30134.el7
                                                                       @base    
texlive-dvipdfmx.noarch                        2:svn26765.0-45.el7     @base    
texlive-dvipdfmx-bin.x86_64                    2:svn26509.0-45.20130427_r30134.el7
                                                                       @base    
texlive-dvipdfmx-def.noarch                    2:svn15878.0-45.el7     @base    
texlive-dvipng.noarch                          2:svn26689.1.14-45.el7  @base    
texlive-dvipng-bin.x86_64                      2:svn26509.0-45.20130427_r30134.el7
                                                                       @base    
texlive-dvips.noarch                           2:svn29585.0-45.el7     @base    
texlive-dvips-bin.x86_64                       2:svn26509.0-45.20130427_r30134.el7
                                                                       @base    
texlive-enctex.noarch                          2:svn28602.0-45.el7     @base    
texlive-enumitem.noarch                        2:svn24146.3.5.2-45.el7 @base    
texlive-epsf.noarch                            2:svn21461.2.7.4-45.el7 @base    
texlive-eso-pic.noarch                         2:svn21515.2.0c-45.el7  @base    
texlive-etex.noarch                            2:svn22198.2.1-45.el7   @base    
texlive-etex-pkg.noarch                        2:svn15878.2.0-45.el7   @base    
texlive-etoolbox.noarch                        2:svn20922.2.1-45.el7   @base    
texlive-euro.noarch                            2:svn22191.1.1-45.el7   @base    
texlive-eurosym.noarch                         2:svn17265.1.4_subrfix-45.el7
                                                                       @base    
texlive-fancyvrb.noarch                        2:svn18492.2.8-45.el7   @base    
texlive-filecontents.noarch                    2:svn24250.1.3-45.el7   @base    
texlive-filehook.noarch                        2:svn24280.0.5d-45.el7  @base    
texlive-float.noarch                           2:svn15878.1.3d-45.el7  @base    
texlive-fontspec.noarch                        2:svn29412.v2.3a-45.el7 @base    
texlive-footmisc.noarch                        2:svn23330.5.5b-45.el7  @base    
texlive-fp.noarch                              2:svn15878.0-45.el7     @base    
texlive-fpl.noarch                             2:svn15878.1.002-45.el7 @base    
texlive-geometry.noarch                        2:svn19716.5.6-45.el7   @base    
texlive-glyphlist.noarch                       2:svn28576.0-45.el7     @base    
texlive-graphics.noarch                        2:svn25405.1.0o-45.el7  @base    
texlive-gsftopk.noarch                         2:svn26689.1.19.2-45.el7
                                                                       @base    
texlive-gsftopk-bin.x86_64                     2:svn26509.0-45.20130427_r30134.el7
                                                                       @base    
texlive-helvetic.noarch                        2:svn28614.0-45.el7     @base    
texlive-hyperref.noarch                        2:svn28213.6.83m-45.el7 @base    
texlive-hyph-utf8.noarch                       2:svn29641.0-45.el7     @base    
texlive-hyphen-base.noarch                     2:svn29197.0-45.el7     @base    
texlive-ifetex.noarch                          2:svn24853.1.2-45.el7   @base    
texlive-ifluatex.noarch                        2:svn26725.1.3-45.el7   @base    
texlive-ifxetex.noarch                         2:svn19685.0.5-45.el7   @base    
texlive-index.noarch                           2:svn24099.4.1beta-45.el7
                                                                       @base    
texlive-kastrup.noarch                         2:svn15878.0-45.el7     @base    
texlive-koma-script.noarch                     2:svn27255.3.11b-45.el7 @base    
texlive-kpathsea.noarch                        2:svn28792.0-45.el7     @base    
texlive-kpathsea-bin.x86_64                    2:svn27347.0-45.20130427_r30134.el7
                                                                       @base    
texlive-kpathsea-lib.x86_64                    2:2012-45.20130427_r30134.el7
                                                                       @base    
texlive-l3kernel.noarch                        2:svn29409.SVN_4469-45.el7
                                                                       @base    
texlive-l3packages.noarch                      2:svn29361.SVN_4467-45.el7
                                                                       @base    
texlive-latex.noarch                           2:svn27907.0-45.el7     @base    
texlive-latex-fonts.noarch                     2:svn28888.0-45.el7     @base    
texlive-latexconfig.noarch                     2:svn28991.0-45.el7     @base    
texlive-listings.noarch                        2:svn15878.1.4-45.el7   @base    
texlive-lm.noarch                              2:svn28119.2.004-45.el7 @base    
texlive-lm-math.noarch                         2:svn29044.1.958-45.el7 @base    
texlive-lua-alt-getopt.noarch                  2:svn29349.0.7.0-45.el7 @base    
texlive-lualatex-math.noarch                   2:svn29346.1.2-45.el7   @base    
texlive-luaotfload.noarch                      2:svn26718.1.26-45.el7  @base    
texlive-luaotfload-bin.noarch                  2:svn18579.0-45.20130427_r30134.el7
                                                                       @base    
texlive-luatex.noarch                          2:svn26689.0.70.1-45.el7
                                                                       @base    
texlive-luatex-bin.x86_64                      2:svn26912.0-45.20130427_r30134.el7
                                                                       @base    
texlive-luatexbase.noarch                      2:svn22560.0.31-45.el7  @base    
texlive-makeindex.noarch                       2:svn26689.2.12-45.el7  @base    
texlive-makeindex-bin.x86_64                   2:svn26509.0-45.20130427_r30134.el7
                                                                       @base    
texlive-marginnote.noarch                      2:svn25880.v1.1i-45.el7 @base    
texlive-marvosym.noarch                        2:svn29349.2.2a-45.el7  @base    
texlive-mathpazo.noarch                        2:svn15878.1.003-45.el7 @base    
texlive-memoir.noarch                          2:svn21638.3.6j_patch_6.0g-45.el7
                                                                       @base    
texlive-metafont.noarch                        2:svn26689.2.718281-45.el7
                                                                       @base    
texlive-metafont-bin.x86_64                    2:svn26912.0-45.20130427_r30134.el7
                                                                       @base    
texlive-mflogo.noarch                          2:svn17487.0-45.el7     @base    
texlive-mfware.noarch                          2:svn26689.0-45.el7     @base    
texlive-mfware-bin.x86_64                      2:svn26509.0-45.20130427_r30134.el7
                                                                       @base    
texlive-misc.noarch                            2:svn24955.0-45.el7     @base    
texlive-mparhack.noarch                        2:svn15878.1.4-45.el7   @base    
texlive-ms.noarch                              2:svn24467.0-45.el7     @base    
texlive-multido.noarch                         2:svn18302.1.42-45.el7  @base    
texlive-ncntrsbk.noarch                        2:svn28614.0-45.el7     @base    
texlive-oberdiek.noarch                        2:svn26725.0-45.el7     @base    
texlive-palatino.noarch                        2:svn28614.0-45.el7     @base    
texlive-paralist.noarch                        2:svn15878.2.3b-45.el7  @base    
texlive-parallel.noarch                        2:svn15878.0-45.el7     @base    
texlive-pdftex.noarch                          2:svn29585.1.40.11-45.el7
                                                                       @base    
texlive-pdftex-bin.x86_64                      2:svn27321.0-45.20130427_r30134.el7
                                                                       @base    
texlive-pgf.noarch                             2:svn22614.2.10-45.el7  @base    
texlive-plain.noarch                           2:svn26647.0-45.el7     @base    
texlive-psnfss.noarch                          2:svn23394.9.2a-45.el7  @base    
texlive-pst-3d.noarch                          2:svn17257.1.10-45.el7  @base    
texlive-pst-coil.noarch                        2:svn24020.1.06-45.el7  @base    
texlive-pst-eps.noarch                         2:svn15878.1.0-45.el7   @base    
texlive-pst-fill.noarch                        2:svn15878.1.01-45.el7  @base    
texlive-pst-grad.noarch                        2:svn15878.1.06-45.el7  @base    
texlive-pst-math.noarch                        2:svn20176.0.61-45.el7  @base    
texlive-pst-node.noarch                        2:svn27799.1.25-45.el7  @base    
texlive-pst-plot.noarch                        2:svn28729.1.44-45.el7  @base    
texlive-pst-text.noarch                        2:svn15878.1.00-45.el7  @base    
texlive-pst-tree.noarch                        2:svn24142.1.12-45.el7  @base    
texlive-pstricks.noarch                        2:svn29678.2.39-45.el7  @base    
texlive-pstricks-add.noarch                    2:svn28750.3.59-45.el7  @base    
texlive-pxfonts.noarch                         2:svn15878.0-45.el7     @base    
texlive-qstest.noarch                          2:svn15878.0-45.el7     @base    
texlive-rsfs.noarch                            2:svn15878.0-45.el7     @base    
texlive-sauerj.noarch                          2:svn15878.0-45.el7     @base    
texlive-setspace.noarch                        2:svn24881.6.7a-45.el7  @base    
texlive-showexpl.noarch                        2:svn27790.v0.3j-45.el7 @base    
texlive-soul.noarch                            2:svn15878.2.4-45.el7   @base    
texlive-subfig.noarch                          2:svn15878.1.3-45.el7   @base    
texlive-symbol.noarch                          2:svn28614.0-45.el7     @base    
texlive-tetex.noarch                           2:svn29585.3.0-45.el7   @base    
texlive-tetex-bin.noarch                       2:svn27344.0-45.20130427_r30134.el7
                                                                       @base    
texlive-tex.noarch                             2:svn26689.3.1415926-45.el7
                                                                       @base    
texlive-tex-bin.x86_64                         2:svn26912.0-45.20130427_r30134.el7
                                                                       @base    
texlive-tex-gyre.noarch                        2:svn18651.2.004-45.el7 @base    
texlive-tex-gyre-math.noarch                   2:svn29045.0-45.el7     @base    
texlive-texconfig.noarch                       2:svn29349.0-45.el7     @base    
texlive-texconfig-bin.noarch                   2:svn27344.0-45.20130427_r30134.el7
                                                                       @base    
texlive-texlive.infra.noarch                   2:svn28217.0-45.el7     @base    
texlive-texlive.infra-bin.x86_64               2:svn22566.0-45.20130427_r30134.el7
                                                                       @base    
texlive-thumbpdf.noarch                        2:svn26689.3.15-45.el7  @base    
texlive-thumbpdf-bin.noarch                    2:svn6898.0-45.20130427_r30134.el7
                                                                       @base    
texlive-times.noarch                           2:svn28614.0-45.el7     @base    
texlive-tipa.noarch                            2:svn29349.1.3-45.el7   @base    
texlive-tools.noarch                           2:svn26263.0-45.el7     @base    
texlive-txfonts.noarch                         2:svn15878.0-45.el7     @base    
texlive-underscore.noarch                      2:svn18261.0-45.el7     @base    
texlive-unicode-math.noarch                    2:svn29413.0.7d-45.el7  @base    
texlive-url.noarch                             2:svn16864.3.2-45.el7   @base    
texlive-utopia.noarch                          2:svn15878.0-45.el7     @base    
texlive-varwidth.noarch                        2:svn24104.0.92-45.el7  @base    
texlive-wasy.noarch                            2:svn15878.0-45.el7     @base    
texlive-wasysym.noarch                         2:svn15878.2.0-45.el7   @base    
texlive-xcolor.noarch                          2:svn15878.2.11-45.el7  @base    
texlive-xdvi.noarch                            2:svn26689.22.85-45.el7 @base    
texlive-xdvi-bin.x86_64                        2:svn26509.0-45.20130427_r30134.el7
                                                                       @base    
texlive-xkeyval.noarch                         2:svn27995.2.6a-45.el7  @base    
texlive-xunicode.noarch                        2:svn23897.0.981-45.el7 @base    
texlive-zapfchan.noarch                        2:svn28614.0-45.el7     @base    
texlive-zapfding.noarch                        2:svn28614.0-45.el7     @base    
time.x86_64                                    1.7-45.el7              @base    
tix.x86_64                                     1:8.4.3-12.el7          @base    
tk.x86_64                                      1:8.5.13-6.el7          @base    
tkinter.x86_64                                 2.7.5-90.el7            @updates 
tmux.x86_64                                    1.8-4.el7               @base    
tokyocabinet.x86_64                            1.4.48-3.el7            @base    
traceroute.x86_64                              3:2.0.22-2.el7          @base    
trousers.x86_64                                0.3.14-2.el7            @base    
ttmkfdir.x86_64                                3.0.9-42.el7            @base    
tuned.noarch                                   2.11.0-11.el7_9         @updates 
tzdata.noarch                                  2021e-1.el7             @updates 
tzdata-java.noarch                             2021e-1.el7             @updates 
unibilium.x86_64                               2.0.0-1.el7             @epel    
unixODBC.x86_64                                2.3.1-14.el7            @base    
unzip.x86_64                                   6.0-24.el7_9            @updates 
urw-base35-bookman-fonts.noarch                20170801-10.el7         @base    
urw-base35-c059-fonts.noarch                   20170801-10.el7         @base    
urw-base35-d050000l-fonts.noarch               20170801-10.el7         @base    
urw-base35-fonts.noarch                        20170801-10.el7         @base    
urw-base35-fonts-common.noarch                 20170801-10.el7         @base    
urw-base35-gothic-fonts.noarch                 20170801-10.el7         @base    
urw-base35-nimbus-mono-ps-fonts.noarch         20170801-10.el7         @base    
urw-base35-nimbus-roman-fonts.noarch           20170801-10.el7         @base    
urw-base35-nimbus-sans-fonts.noarch            20170801-10.el7         @base    
urw-base35-p052-fonts.noarch                   20170801-10.el7         @base    
urw-base35-standard-symbols-ps-fonts.noarch    20170801-10.el7         @base    
urw-base35-z003-fonts.noarch                   20170801-10.el7         @base    
usermode.x86_64                                1.111-6.el7             @base    
ustr.x86_64                                    1.0.4-16.el7            installed
util-linux.x86_64                              2.23.2-65.el7_9.1       @updates 
vim-common.x86_64                              2:7.4.629-8.el7_9       @updates 
vim-enhanced.x86_64                            2:7.4.629-8.el7_9       @updates 
vim-filesystem.x86_64                          2:7.4.629-8.el7_9       @updates 
vim-minimal.x86_64                             2:7.4.629-8.el7_9       @updates 
virt-what.x86_64                               1.18-4.el7_9.1          @updates 
vnu.x86_64                                     17.11.1-2.2.cpanel      @cp-dev-tools
vulkan.x86_64                                  1.1.97.0-1.el7          @base    
vulkan-filesystem.noarch                       1.1.97.0-1.el7          @base    
wget.x86_64                                    1.14-18.el7_6.1         @base    
which.x86_64                                   2.20-7.el7              installed
wp-toolkit-cpanel.x86_64                       5.9.1-3206              @wp-toolkit-cpanel
wpa_supplicant.x86_64                          1:2.6-12.el7_9.2        @updates 
xdelta.x86_64                                  3.0.7-4.el7             @base    
xdg-utils.noarch                               1.1.0-0.17.20120809git.el7
                                                                       @base    
xfsprogs.x86_64                                4.5.0-22.el7            @base    
xinetd.x86_64                                  2:2.3.15-14.el7         @base    
xkeyboard-config.noarch                        2.24-1.el7              @base    
xml-common.noarch                              0.6.3-39.el7            @base    
xmlrpc-c.x86_64                                1.32.5-1905.svn2451.el7 @base    
xmlto.x86_64                                   0.0.25-7.el7            @base    
xorg-x11-font-utils.x86_64                     1:7.5-21.el7            @base    
xorg-x11-fonts-ISO8859-1-75dpi.noarch          7.5-9.el7               @base    
xorg-x11-fonts-Type1.noarch                    7.5-9.el7               @base    
xorg-x11-proto-devel.noarch                    2018.4-1.el7            @base    
xorg-x11-server-utils.x86_64                   7.7-20.el7              @base    
xxhash-libs.x86_64                             0.8.1-1.el7             @epel    
xz.x86_64                                      5.2.2-1.el7             installed
xz-devel.x86_64                                5.2.2-1.el7             @base    
xz-libs.x86_64                                 5.2.2-1.el7             installed
xz-lzma-compat.x86_64                          5.2.2-1.el7             @base    
yajl.x86_64                                    2.0.4-4.el7             @base    
yum.noarch                                     3.4.3-168.el7.centos    @base    
yum-metadata-parser.x86_64                     1.1.4-10.el7            installed
yum-plugin-fastestmirror.noarch                1.1.31-54.el7_8         @base    
yum-plugin-universal-hooks.x86_64              0.1-12.18.1.cpanel      @EA4-developer-feed
yum-rhn-plugin.noarch                          2.0.1-10.el7            @base    
yum-utils.noarch                               1.1.31-54.el7_8         @base    
zip.x86_64                                     3.0-11.el7              @base    
zlib.x86_64                                    1.2.7-19.el7_9          @updates 
zlib-devel.x86_64                              1.2.7-19.el7_9          @updates 
zlib-static.x86_64                             1.2.7-19.el7_9          @updates 
zork.x86_64                                    1.0.3-1.el7             @epel    
zsh.x86_64                                     5.0.2-34.el7_8.2        @base    
zziplib.x86_64                                 0.13.62-12.el7          @base    
