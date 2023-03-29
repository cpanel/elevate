package Elevate::Motd;

use cPstrict;

sub setup {

    my $f = _motd_file();

    my $notice = _motd_notice_message();

    local $/;
    my $fh;
    my $content = '';

    if ( open( $fh, '+<', $f ) ) {
        $content = <$fh> // '';
    }
    elsif ( open( $fh, '>', $f ) ) {
        1;
    }

    return 0 if $content =~ qr{elevate in progress}mi;

    print {$fh} "\n" if length($content) && $content !~ qr{\n\z};

    print {$fh} $notice;

    return 1;
}

sub cleanup {

    my $f = _motd_file();

    my $content;
    open( my $fh, '+<', $f ) or return;
    {
        local $/;
        $content = <$fh>;
    }

    return 0 unless $content && $content =~ qr{elevate in progress}mi;

    my $notice = _motd_notice_message();

    if ( $content =~ s{\Q$notice\E}{} ) {
        seek( $fh, 0, 0 );
        print {$fh} $content;
        truncate( $fh, tell($fh) );
        close($fh);

        return 1;
    }

    return;
}

sub _motd_notice_message {
    return <<~'EOS';
    # -----------------------------------------------------------------------------
    #
    # /!\ ELEVATE IN PROGRESS /!\
    #
    # Do not make any changes until it's complete
    # you can check the current process status by running:
    #
    #           /scripts/elevate-cpanel --status
    #
    # Or monitor the progress by running:
    #
    #           /scripts/elevate-cpanel --log
    #
    # -----------------------------------------------------------------------------
    EOS
}

sub _motd_file {    # allow us to mock it, we cannot use Test::MockFile GH #77 - https://github.com/cpanel/Test-MockFile/issues/77
    return q[/etc/motd];
}

1;
