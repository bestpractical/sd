package App::SD::Util;
use DateTime;
use Params::Validate qw/:all/;

sub string_to_datetime {
    my ($date)= validate_pos(@_, { type => SCALAR | UNDEF} );
    if ($date =~ /^(\d{4})-(\d{2})-(\d{2})[T\s](\d{1,2}):(\d{2}):(\d{2})Z?$/ ){
        my ($year,$month,$day, $hour,$min,$sec) = ($1,$2,$3,$4,$5,$6);
        my $dt = DateTime->new( year => $year,
                                month => $month,
                                day => $day,
                                hour => $hour,
                                minute => $min,
                                second => $sec,
                                time_zone => 'GMT');
        return $dt;
    }
    elsif (
        $date =~ m!^(\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2}) ([-+]?\d{4})?! )
    {
        # e.g. 2009/03/21 10:03:05 -0700
        my ( $year, $month, $day, $hour, $min, $sec, $tz ) =
          ( $1, $2, $3, $4, $5, $6, $7 );
        my $dt = DateTime->new(
            year      => $year,
            month     => $month,
            day       => $day,
            hour      => $hour,
            minute    => $min,
            second    => $sec,
            time_zone => $tz || 'GMT'
        );
        $dt->set_time_zone( 'GMT' );
        return $dt;
    }
    elsif ($date) {
        require DateTime::Format::Natural;
        # XXX DO we want floating or GMT?
        my $parser = DateTime::Format::Natural->new(time_zone => 'floating');
        my $dt = $parser->parse_datetime($date);
        if ($parser->success) {
            return $dt;
        } 
    }
    return undef;
}

1;
