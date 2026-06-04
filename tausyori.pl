#!/usr/bin/perl
use strict;
use warnings;

use CGI ":standard";
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use lib qw(/var/www/html/heart/mod);
use Data::Dump qw(dump);
use DateTime;
use DBI;
use URI;
use JSON;
use open qw( :std :encoding(utf8) );
use utf8;
use Encode qw( decode_utf8 );
use POSIX;

use Kahifu::Junbi;
use Kahifu::Template qw{dict};
use Kahifu::Setuzoku;
use Hyouka::Infra qw(jyoukyou_settei midasi_settei sakka_settei date date_split url_get_tuke url_get_hazusi week week_border week_count week_delta hash_max_key timestamp_syutoku);
use Hyouka::External;

if(request_method eq 'POST' && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');

    my %params;
	foreach (param) {
		$params{$_} = [ param($_) ];
		$params{$_} = $params{$_}[0] if @{$params{$_}} == 1;
	}

    my $id = defined $params{'id'} && $params{'id'} ne '' ? (ref $params{'id'} eq 'ARRAY' ? $params{'id'} : [$params{'id'}]) : undef;
    my $sid = defined $params{'sid'} && $params{'sid'} ne '' ? (ref $params{'sid'} eq 'ARRAY' ? $params{'sid'} : [$params{'sid'}]) : undef;
    my $pid = defined $params{'pid'} && $params{'pid'} ne '' ? (ref $params{'pid'} eq 'ARRAY' ? $params{'pid'} : [$params{'pid'}]) : undef;
    my $genpart = defined $params{'genpart'} && $params{'genpart'} ne '' ? (ref $params{'genpart'} eq 'ARRAY' ? $params{'genpart'} : [$params{'genpart'}]) : undef;
    my $part = defined $params{'part'} && $params{'part'} ne '' ? (ref $params{'part'} eq 'ARRAY' ? $params{'part'} : [$params{'part'}]) : undef;
    my $whole = defined $params{'whole'} && $params{'whole'} ne '' ? (ref $params{'whole'} eq 'ARRAY' ? $params{'whole'} : [$params{'whole'}]) : undef;
    my $josuu = defined $params{'josuu'} && $params{'josuu'} ne '' ? (ref $params{'josuu'} eq 'ARRAY' ? $params{'josuu'} : [$params{'josuu'}]) : undef;
    my $hajimari = defined $params{'hajimari'} && $params{'hajimari'} ne '' ? (ref $params{'hajimari'} eq 'ARRAY' ? $params{'hajimari'} : [$params{'hajimari'}]) : undef;
    my $jiten = defined $params{'jiten'} && $params{'jiten'} ne '' ? (ref $params{'jiten'} eq 'ARRAY' ? $params{'jiten'} : [$params{'jiten'}]) : undef;
    my $memo = defined $params{'memo'} && $params{'memo'} ne '' ? (ref $params{'memo'} eq 'ARRAY' ? $params{'memo'} : [$params{'memo'}]) : undef;
    my $with = defined $params{'with'} && $params{'with'} ne '' ? (ref $params{'with'} eq 'ARRAY' ? $params{'with'} : [$params{'with'}]) : undef;
    my $mode = defined $params{'mode'} && $params{'mode'} ne '' ? (ref $params{'mode'} eq 'ARRAY' ? $params{'mode'} : [$params{'mode'}]) : undef;

    #die dump %params;
    my $meirei;
    my @param_keys = keys %params;
    for my $i (0 .. scalar @param_keys - 1){
        if(index($param_keys[$i], 'meirei') != -1){
            push @{$meirei}, $params{$param_keys[$i]};
        }
    }

    my $abs_url = URI->new( CGI::url(-full => 1) ) . '';
    my $page_url = URI->new( CGI::url(-relative => 1) ) . '';
    $abs_url =~ s/$page_url/kousin.pl/;

    for my $j (reverse 0 .. scalar @{$meirei} - 1){
        if($meirei->[$j] != 0){
            my $tau_kousin_query = "update `tautulli` set status = ? where id = ?";
		    my $tau_kousin = $dbh->prepare($tau_kousin_query);
		    $tau_kousin->execute($meirei->[$j], $id->[$j]);
        }
        if($meirei->[$j] == 2 && defined $sid->[$j] && $sid->[$j] ne ''){
            my $tau_kousin_query = "insert into `tautulli_match` (sid, pid) select * from (select ?, ?) as t where not exists (select pid from `tautulli_match` where sid = ? and pid = ?) limit 1";
            my $tau_kousin = $dbh->prepare($tau_kousin_query);
            $tau_kousin->execute($sid->[$j], $pid->[$j], $sid->[$j], $pid->[$j]);

            my $sakuhin_syutoku_query = ("select whole, yotei from sakuhin where `id` = ?");
			my $sakuhin_syutoku = $dbh->prepare($sakuhin_syutoku_query);
			$sakuhin_syutoku->execute($sid->[$j]);
			my $v = $sakuhin_syutoku->fetchrow_hashref;
			my $whole = $v->{whole};
            my $yotei = $v->{yotei};

            my $ua = LWP::UserAgent->new();
            $ua->agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:143.0) Gecko/20100101 Firefox/143.0");
            my $response;
            if($yotei == 1){
                $response = $ua->post($abs_url,
                "Cookie" => $ENV{HTTP_COOKIE},
                Content => {
                    'reference' => $sid->[$j],
                    'part' => $part->[$j],
                    'whole' => $whole,
                    'josuu' => '儘',
                    'title' => $memo->[$j],
                    'with' => $with->[$j],
                    'unix_owari' => $jiten->[$j],
                    'unix_hajimari' => $hajimari->[$j],
                    'mode' => $mode->[$j],
                    'jikoku_mikakutei' => 0,
                    'ikkatu' => 1
                });
            } else {
                $response = $ua->post($abs_url,
                "Cookie" => $ENV{HTTP_COOKIE},
                Content => {
                    'reference' => $sid->[$j],
                    'part' => $part->[$j],
                    'whole' => $whole,
                    'josuu' => '儘',
                    'title' => $memo->[$j],
                    'with' => $with->[$j],
                    'unix_owari' => $jiten->[$j],
                    'mode' => $mode->[$j],
                    'jikoku_mikakutei' => 0,
                    'ikkatu' => 1
                });
            }
            my $content = $response->as_string();
            #die dump $content;
        }
    }
}

my $query=new CGI;
print $query->redirect($ENV{HTTP_REFERER});
print "Content-type: text/html; charset=utf-8\n\n";