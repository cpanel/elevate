package Elevate::Components::PerlXS;

=encoding utf-8

=head1 NAME

Elevate::Components::PerlXS

Capture and reinstall Perl XS packages.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::Notify    ();
use Elevate::StageFile ();

use Config;
use Cwd           ();
use Log::Log4perl qw(:easy);
use File::Find    ();

use parent qw{Elevate::Components::Base};

use constant DISTRO_PERL_XS_PATH => '/usr/local/lib64/perl5';

sub pre_distro_upgrade ($self) {

    $self->purge_perl_xs(DISTRO_PERL_XS_PATH);
    $self->purge_perl_xs( $Config{'installsitearch'} );

    return;
}

sub post_distro_upgrade ($self) {

    $self->restore_perl_xs(DISTRO_PERL_XS_PATH);
    $self->restore_perl_xs( $Config{'installsitearch'} );

    return;
}

sub purge_perl_xs ( $self, $path ) {

    return unless length $path && -d $path;

    my @perl_modules;

    File::Find::find(
        sub {
            return unless substr( $_, -3 ) eq '.pm';
            return if -l $_;
            return unless -f $_;

            push @perl_modules, $File::Find::name;

        },
        $path
    );

    my $path_len = length($path);
    @perl_modules = map { substr( $_, $path_len + 1 ) } sort { $a cmp $b } @perl_modules;

    my $xspm_to_rpm = xspm_to_rpm();

    my %rpms_to_restore;
    my @modules_to_restore;
    foreach my $file (@perl_modules) {

        # We can only convert distro perl arch perl modules to RPM.
        if ( $path eq DISTRO_PERL_XS_PATH && length $xspm_to_rpm->{$file} ) {
            $rpms_to_restore{$file} = $xspm_to_rpm->{$file};
        }
        else {
            push @modules_to_restore, $file;
        }
    }

    my $pretty_distro_name = $self->upgrade_to_pretty_name();

    my $stash = {};
    if (%rpms_to_restore) {
        INFO("The following `cpan` installed perl Modules will be removed and replaced with a $pretty_distro_name RPM after upgrade:");
        foreach my $file ( sort { $rpms_to_restore{$a} cmp $rpms_to_restore{$b} || $a cmp $b } keys %rpms_to_restore ) {
            INFO( sprintf( "  %20s => %s", $file, $rpms_to_restore{$file} ) );

            my $files_in_rpm = $stash->{'restore'}->{$path}->{'rpm'}->{ $rpms_to_restore{$file} } //= [];
            unless ( grep { $_ eq $file } @$files_in_rpm ) {    # Only if we've not stored this.
                push @$files_in_rpm, $file;
                unlink "$path/$file";
            }
        }
        INFO(' ');
    }

    if (@modules_to_restore) {
        WARN("The following modules will likely not be functional on $pretty_distro_name and will be disabled. You will need to restore these manually:");
        my $to_restore = $stash->{'restore'}->{$path}->{'cpan'} //= [];
        foreach my $file (@modules_to_restore) {
            WARN("    $path/$file");
            next if grep { $_ eq $file } @$to_restore;    # We've already stashed this.
            push @$to_restore, $file;
            rename "$path/$file", "$path/$file.o";
        }
    }

    Elevate::StageFile::update_stage_file($stash);

    return;
}

sub restore_perl_xs ( $self, $path ) {
    my $stash = Elevate::StageFile::read_stage_file();

    if ( $path eq DISTRO_PERL_XS_PATH ) {
        my $rpms = $stash->{'restore'}->{ DISTRO_PERL_XS_PATH() }->{'rpm'};

        if ( scalar keys %$rpms ) {    # If there are no XS modules to replace, there is no point to running the dnf install:
            my @cmd = ( '/usr/bin/dnf', '-y', '--enablerepo=epel', '--enablerepo=powertools', 'install', sort keys %$rpms );
            $self->ssystem(@cmd);
        }
    }

    my $cpan_modules = $stash->{$path}->{'cpan'} // return;

    # TODO: Let's restore this with /usr/bin/cpan!
    my $msg = "The following XS modules will need to be re-installed:\n\n";
    foreach my $module (@$cpan_modules) {
        $msg .= "   $module\n";
    }

    Elevate::Notify::add_final_notification($msg);

    return;
}

sub xspm_to_rpm () {
    return {
        'IO/Pty.pm'           => 'perl-IO-Tty',
        'IO/Tty.pm'           => 'perl-IO-Tty',
        'IO/Tty/Constant.pm'  => 'perl-IO-Tty',
        'JSON/Syck.pm'        => 'perl-YAML-Syck',
        'JSON/XS.pm'          => 'perl-JSON-XS',
        'JSON/XS/Boolean.pm'  => 'perl-JSON-XS',
        'YAML/Dumper/Syck.pm' => 'perl-YAML-Syck',
        'YAML/Loader/Syck.pm' => 'perl-YAML-Syck',
        'YAML/Syck.pm'        => 'perl-YAML-Syck',
        'common/sense.pm'     => 'perl-common-sense',
        'version.pm'          => 'perl-version',
        'version/regex.pm'    => 'perl-version',
        'version/vpp.pm'      => 'perl-version',
        'version/vxs.pm'      => 'perl-version',
    };
}

1;
