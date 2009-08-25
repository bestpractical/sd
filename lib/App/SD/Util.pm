package App::SD::Util;
use Any::Moose; # for warnings and strict at the least
use DateTime;
use Params::Validate qw/:all/;


my %MONTHS = ( jan => 1, feb => 2, mar => 3, apr => 4, may => 5, jun => 6, jul => 7, aug => 8, sep => 9, oct => 10, nov => 11, dec => 12);


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
    if ( $date =~ m!^(\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2}) ([-+]?\d{4})?! ) {
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
 
	#Thu Jun 11 05:21:26 -0700 2009 - as github was broken on 2009-08-25
	if ($date =~ /^(\w{3}) (\w{3}) (\d+) (\d\d):(\d\d):(\d\d) ([+-]?\d{4}) (\d{4})$/) {
        my ( $wday, $mon, $day, $hour, $min, $sec, $tz, $year) = 
          ( $1, $2, $3, $4, $5, $6, $7, $8 );
        my $dt = DateTime->new(
            year      => $year,
            month     => $MONTHS{lc($mon)},
            day       => $day,
            hour      => $hour,
            minute    => $min,
            second    => $sec,
            time_zone => $tz || 'GMT'
        );
        $dt->set_time_zone( 'GMT' );
        return $dt;

	}



	if ($date) {
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
