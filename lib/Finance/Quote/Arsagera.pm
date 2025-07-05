=encoding utf8

=head1 NAME

Finance::Quote::Arsagera - Получение данных о фондах с arsagera.ru через Finance::Quote

=head1 VERSION

Version 0.02

=head1 AUTHOR

Sphex <sphex@cpan.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=head1 SYNOPSIS

    use Finance::Quote;

    my $q = Finance::Quote->new("Arsagera");
    my %info = $q->fetch("arsagera", "ArsFA");

    print "NAV: ", $info{"ArsFA", "nav"}, "\n";

=head1 DESCRIPTION

Этот модуль предоставляет поддержку получения информации о фондах с сайта
L<https://arsagera.ru> через публичное API.

I<'ArsFA'>   - "Арсагера — фонд акций"
I<'ArsF4SI'> - "Арсагера — фонд смешанных инвестиций"
I<'ArsF64'>  - "Арсагера — акции 6.4"
I<'ArsFO'>   - "Арсагера – фонд облигаций КР 1.55"

=head1 METHODS

=over 4

=item B<arsagera>

Основной метод, вызываемый Finance::Quote для получения данных о фондах.

=item B<methods>

Возвращает хэш с именем метода и ссылкой на реализацию, чтобы зарегистрировать его в Finance::Quote.

=item B<labels>

Возвращает список меток данных, которые может предоставлять этот модуль:
name, nav, date, isodate, currency.

=item B<get_date>

Вспомогательная функция, которая возвращает дату в формате YYYY-MM-DD как строку.
Принимает число дней назад, от которого нужно вычислить дату.

=back

=cut

package Finance::Quote::Arsagera;

use 5.010;
use strict;
use warnings;
use base 'Finance::Quote';

use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;
use Time::Piece;

our $VERSION = '0.02';

sub methods {
    return ( arsagera => \&arsagera );
}

{
    my @labels = qw/name nav date isodate currency/;
    sub labels {
        return ( arsagera => \@labels );
    }
}

sub arsagera {
    my ($quoter, @funds) = @_;
    my %info;

    my $ua = LWP::UserAgent->new;
    $ua->agent("Finance::Quote::Arsagera/$VERSION");
    $ua->timeout(10);

    foreach my $fund (@funds) {
        my $fund_code;
        if    ($fund eq 'ArsFA')   { $fund_code = 'fa'; }    # "Арсагера — фонд акций"
        elsif ($fund eq 'ArsF4SI') { $fund_code = 'f4si'; }  # "Арсагера — фонд смешанных инвестиций"
        elsif ($fund eq 'ArsF64')  { $fund_code = 'f64'; }   # "Арсагера — акции 6.4"
        elsif ($fund eq 'ArsFO')   { $fund_code = 'fo'; }    # "Арсагера – фонд облигаций КР 1.55"
        else                       { next; }

        my $from = get_date(15);
        my $to   = get_date(0);

        my $url = "https://arsagera.ru/api/v1/funds/$fund_code/fund-metrics/?from=$from&to=$to";
        my $response = $ua->request(GET $url);

        if (!$response->is_success) {
            $info{"$fund", "success"} = 0;
            $info{"$fund", "errormsg"} = "HTTP error: " . $response->status_line;
            next;
        }

        my $data;
        eval {
            $data = decode_json($response->decoded_content);
        };
        if ($@) {
            $info{"$fund", "success"} = 0;
            $info{"$fund", "errormsg"} = "Failed to parse JSON";
            next;
        }

        if (!exists $data->{data} || !ref $data->{data} || scalar @{$data->{data}} == 0) {
            $info{"$fund", "success"} = 0;
            $info{"$fund", "errormsg"} = "No data returned from API";
            next;
        }

        my $latest = $data->{data}->[-1];
        my $nav    = $latest->{nav_per_share};
        my $date   = $latest->{date};

        $info{"$fund", "success"} = 1;
        $info{"$fund", "name"} = $fund;
        $info{"$fund", "symbol"} = $fund;
        $info{"$fund", "nav"} = $nav;
        $info{"$fund", "isodate"} = $date;
        $info{"$fund", "date"} = $date;
        $info{"$fund", "currency"} = 'RUB';
        $info{"$fund", "method"} = 'arsagera';

        $quoter->store_date(\%info, $fund, { isodate => $date });
    }

    return wantarray ? %info : \%info;
}

sub get_date {
    my $days_ago = shift;
    my $date = localtime(time() - $days_ago * 86400);
    return $date->strftime('%Y-%m-%d');
}

1;
