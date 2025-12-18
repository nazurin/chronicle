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
use List::Util qw(min max);
use LWP::UserAgent;
use LWP::Authen::OAuth2;
use open qw( :std :encoding(utf8) );
use utf8;
use Encode qw( decode_utf8 );
use POSIX;

use Kahifu::Junbi;
use Kahifu::Template qw{dict};
use Kahifu::Setuzoku;
use Kahifu::Key;
use Hyouka::Infra qw(jyoukyou_settei midasi_settei sakka_settei date date_split url_get_tuke url_get_hazusi week week_border week_count week_delta hash_max_key timestamp_syutoku config_syutoku);
use Hyouka::External qw(access_token_mukou mal_authorize al_authorize audioscrobbler_kousin);

#print "Content-type: text/html; charset=utf-8\n\n";

if(Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
    #audioscrobblerを組み込む
	Hyouka::External::audioscrobbler_kousin($dbh);

    my $yonnsyuukan = time() - 1209600; #2週間

    my $info_audioscrobbler_count_query = "select `id` from `listen` where `date` > ${yonnsyuukan}";
	my $info_audioscrobbler_syutoku = $dbh->prepare($info_audioscrobbler_count_query);
	$info_audioscrobbler_syutoku->execute();
	my $yonsyuukan_rows = $info_audioscrobbler_syutoku->rows;

    my (@hamarimono, @yonsyuukan_uta, @yonsyuukan_kasyu, @yonsyuukan_album);
    my $info_audioscrobbler_uta_query = "select `name`, count(*) as `count` from `listen` where `date` > ${yonnsyuukan} group by `name` order by `count` desc, `date` desc limit 5";
	my $info_audioscrobbler_syutoku = $dbh->prepare($info_audioscrobbler_uta_query);
	$info_audioscrobbler_syutoku->execute();
	while(my $v = $info_audioscrobbler_syutoku->fetchrow_arrayref){
		push @yonsyuukan_uta, { uta => $v->[0], kaisuu => $v->[1]};
	}
    my $info_audioscrobbler_album_query = "select `album`, count(*) as `count`, `date` from `listen` where `date` > ${yonnsyuukan} group by `album` order by `count` desc, `date` desc limit 5";
	my $info_audioscrobbler_syutoku = $dbh->prepare($info_audioscrobbler_album_query);
	$info_audioscrobbler_syutoku->execute();
	while(my $v = $info_audioscrobbler_syutoku->fetchrow_arrayref){
		push @yonsyuukan_album, { album => $v->[0], kaisuu => $v->[1], date => $v->[2]};
	}
    my $info_audioscrobbler_kasyu_query = "select `artist`, count(*) as `count`, `date` from `listen` where `date` > ${yonnsyuukan} group by `artist` order by `count` desc, `date` desc limit 5";
	my $info_audioscrobbler_syutoku = $dbh->prepare($info_audioscrobbler_kasyu_query);
	$info_audioscrobbler_syutoku->execute();
	while(my $v = $info_audioscrobbler_syutoku->fetchrow_arrayref){
		push @yonsyuukan_kasyu, { kasyu => $v->[0], kaisuu => $v->[1], date => $v->[2]};
	}
    push @hamarimono, { namae => $yonsyuukan_uta[0]{uta}, date => $yonsyuukan_uta[0]{date}, syurui => 'uta', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/8)) } if $yonsyuukan_uta[0]{kaisuu} >= 5;
    push @hamarimono, { namae => $yonsyuukan_uta[1]{uta}, date => $yonsyuukan_uta[1]{date}, syurui => 'uta', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/8)) } if $yonsyuukan_uta[1]{kaisuu} >= 7;
    push @hamarimono, { namae => $yonsyuukan_uta[2]{uta}, date => $yonsyuukan_uta[2]{date}, syurui => 'uta', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/8)) } if $yonsyuukan_uta[2]{kaisuu} >= 9;
    push @hamarimono, { namae => $yonsyuukan_album[0]{album}, date => $yonsyuukan_album[0]{date},  syurui => 'album', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/40)) } if 100*($yonsyuukan_album[0]{kaisuu} / $yonsyuukan_rows) >= 20;
    push @hamarimono, { namae => $yonsyuukan_album[1]{album}, date => $yonsyuukan_album[1]{date},  syurui => 'album', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/30)) } if 100*($yonsyuukan_album[1]{kaisuu} / $yonsyuukan_rows) >= 20;
    push @hamarimono, { namae => $yonsyuukan_album[2]{album}, date => $yonsyuukan_album[2]{date},  syurui => 'album', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/30)) } if 100*($yonsyuukan_album[2]{kaisuu} / $yonsyuukan_rows) >= 20;
    push @hamarimono, { namae => $yonsyuukan_kasyu[0]{kasyu},  syurui => 'kasyu', jiten => '', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/40)) } if 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows) >= 30;
    push @hamarimono, { namae => $yonsyuukan_kasyu[1]{kasyu},  syurui => 'kasyu', jiten => '', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/30)) } if 100*($yonsyuukan_kasyu[1]{kaisuu} / $yonsyuukan_rows) >= 20;
    push @hamarimono, { namae => $yonsyuukan_kasyu[2]{kasyu},  syurui => 'kasyu', jiten => '', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/30)) } if 100*($yonsyuukan_kasyu[2]{kaisuu} / $yonsyuukan_rows) >= 20;

    push @hamarimono, { namae => $yonsyuukan_kasyu[0]{kasyu},  syurui => 'kasyu', jiten => '', hamari => 0, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/40)) } if !(100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows) >= 30);
    push @hamarimono, { namae => $yonsyuukan_kasyu[1]{kasyu},  syurui => 'kasyu', jiten => '', hamari => 0, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[1]{kaisuu} / $yonsyuukan_rows)/40)) } if !(100*($yonsyuukan_kasyu[1]{kaisuu} / $yonsyuukan_rows) >= 20);
    #sub hamarimono_syori {
    #    my $namae = shift;
    #    my $syurui = shift;
    #    my $jiten = shift;
    #    my ($url, $hamarigazou);
    #    if($syurui eq 'kasyu'){
    #        $url = "http://ws.audioscrobbler.com/2.0/?method=artist.search&artist=${namae}&api_key=@{[Kahifu::Key::api_key]}&format=json";
    #        my $request = LWP::UserAgent->new;
    #        my $response = $request->get($url);
#
    #        if ($response->is_success) {
    #            my $content = $response->decoded_content;
    #            my $json = from_json(decode_utf8($content));
    #            return $hamarigazou = $json->{results}{artistmatches}{'artist'}[0]{image}[2]{'#text'};
    #        }
    #    } elsif($syurui eq 'uta' || $syurui eq 'album'){
    #        my $jitenitibyougo = $jiten + 1;
    #        $url = "https://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&user=kazmea&api_key=@{[Kahifu::Key::api_key]}&format=json&limit=20&from=${jiten}&to=${jitenitibyougo}";
    #        my $request = LWP::UserAgent->new;
    #        my $response = $request->get($url);
    #        if ($response->is_success) {
    #            my $content = $response->decoded_content;
    #            my $json = from_json(decode_utf8($content));
    #            return $hamarigazou = $json->{recenttracks}{'track'}[0]{image}[2]{'#text'};
    #        }
    #    }
    #}
    #for my $i (0 .. scalar @hamarimono - 1){
    #    $hamarimono[$i]->{gazou} = hamarimono_syori($hamarimono[$i]->{namae}, $hamarimono[$i]->{syurui}, $hamarimono[$i]->{jiten});
    #}

    my $config = config_syutoku();
    $config->{hamarimono} = \@hamarimono;
    $config->{kousinji} = time();
    config_kousin($config);
}

if(defined param('kyousei') && param('kyousei') eq '1'){
    my $query=new CGI;
    print $query->redirect($ENV{HTTP_REFERER});
    print "Content-type: text/html; charset=utf-8\n\n";
}