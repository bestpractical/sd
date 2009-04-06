package App::SD::Util;
use DateTime;

sub string_to_datetime {
    my $date= shift;
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
    } elsif ($date) {
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
