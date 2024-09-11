package Elevate::Components::cPanelPrep;

=encoding utf-8

=head1 NAME

Elevate::Components::cPanelPrep

Perform tasks to ensure cPanel is in a safe state to upgrade the distro.

=cut

use cPstrict;

use File::Slurper  ();
use File::Basename ();

use Elevate::Constants        ();
use Elevate::StageFile        ();
use Elevate::SystemctlService ();

use Cpanel::FileUtils::TouchFile ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    # Remove scripts/upcp and bin/backup to make sure they don't
    # end up running while ELevate is running.
    unlink('/usr/local/cpanel/scripts/upcp');
    unlink('/usr/local/cpanel/bin/backup');

    $self->_flush_task_queue();
    $self->_disable_all_cpanel_services();
    $self->_setup_outdated_services();
    $self->_suspend_chkservd();

    return;
}

sub _flush_task_queue ($self) {
    INFO('Running all queued cPanel tasks...');
    $self->ssystem(qw{/usr/local/cpanel/bin/servers_queue run});
    return;
}

sub _suspend_chkservd ($self) {
    INFO('Suspending cPanel service monitoring...');
    Cpanel::FileUtils::TouchFile::touchfile(Elevate::Constants::CHKSRVD_SUSPEND_FILE);
    return;
}

sub _setup_outdated_services ($self) {

    INFO('Verifying elevate service is up to date...');

    my $content                = '';
    my $outdated_services_file = Elevate::Constants::IGNORE_OUTDATED_SERVICES_FILE;

    if ( -e $outdated_services_file ) {
        $content = File::Slurper::read_binary($outdated_services_file) // '';
    }

    my $service      = Elevate::Service->new( cpev => $self->cpev );
    my $service_name = $service->short_name;

    return if $content =~ qr{^${service_name}$}m;

    chomp($content);

    $content .= "\n" if length $content;
    $content .= $service_name . "\n";

    my $dirname = File::Basename::dirname($outdated_services_file);
    if ( !-d $dirname ) {
        mkdir($dirname) or die qq[Failed to create directory $dirname - $!];
    }
    File::Slurper::write_binary( $outdated_services_file, $content );

    return 1;
}

sub _disable_all_cpanel_services ($self) {

    INFO('Disabling cPanel services...');

    my @cpanel_services = qw/
      cpanel cpdavd cpgreylistd cphulkd cpipv6
      cpcleartaskqueue
      dnsadmin dovecot exim ipaliases mailman
      mysqld pdns proftpd queueprocd spamd
      crond tailwatchd
      lsws
      /;
    my @disabled_services;

    foreach my $name (@cpanel_services) {
        my $service = Elevate::SystemctlService->new( name => $name );

        next unless $service->is_enabled;
        $service->disable;

        push @disabled_services, $name;
    }
    Elevate::StageFile::update_stage_file( { 'disabled_cpanel_services' => [ sort @disabled_services ] } );

    return;
}

1;

