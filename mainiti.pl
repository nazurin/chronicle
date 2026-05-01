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
use Scalar::Util qw(looks_like_number);

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
    push @hamarimono, { namae => $yonsyuukan_album[0]{album}, date => $yonsyuukan_album[0]{date},  syurui => 'album', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/40)) } if $yonsyuukan_rows > 0 && 100*($yonsyuukan_album[0]{kaisuu} / $yonsyuukan_rows) >= 20;
    push @hamarimono, { namae => $yonsyuukan_album[1]{album}, date => $yonsyuukan_album[1]{date},  syurui => 'album', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/30)) } if $yonsyuukan_rows > 0 && 100*($yonsyuukan_album[1]{kaisuu} / $yonsyuukan_rows) >= 20;
    push @hamarimono, { namae => $yonsyuukan_album[2]{album}, date => $yonsyuukan_album[2]{date},  syurui => 'album', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/30)) } if $yonsyuukan_rows > 0 && 100*($yonsyuukan_album[2]{kaisuu} / $yonsyuukan_rows) >= 20;
    push @hamarimono, { namae => $yonsyuukan_kasyu[0]{kasyu},  syurui => 'kasyu', jiten => '', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/40)) } if $yonsyuukan_rows > 0 && 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows) >= 30;
    push @hamarimono, { namae => $yonsyuukan_kasyu[1]{kasyu},  syurui => 'kasyu', jiten => '', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/30)) } if $yonsyuukan_rows > 0 && 100*($yonsyuukan_kasyu[1]{kaisuu} / $yonsyuukan_rows) >= 20;
    push @hamarimono, { namae => $yonsyuukan_kasyu[2]{kasyu},  syurui => 'kasyu', jiten => '', hamari => 1, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/30)) } if $yonsyuukan_rows > 0 && 100*($yonsyuukan_kasyu[2]{kaisuu} / $yonsyuukan_rows) >= 20;

    push @hamarimono, { namae => $yonsyuukan_kasyu[0]{kasyu},  syurui => 'kasyu', jiten => '', hamari => 0, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows)/40)) } if $yonsyuukan_rows > 0 && !(100*($yonsyuukan_kasyu[0]{kaisuu} / $yonsyuukan_rows) >= 30);
    push @hamarimono, { namae => $yonsyuukan_kasyu[1]{kasyu},  syurui => 'kasyu', jiten => '', hamari => 0, hamarido => 6 * min((1, 100*($yonsyuukan_kasyu[1]{kaisuu} / $yonsyuukan_rows)/40)) } if $yonsyuukan_rows > 0 && !(100*($yonsyuukan_kasyu[1]{kaisuu} / $yonsyuukan_rows) >= 20);

    my $config = config_syutoku();
    $config->{hamarimono} = \@hamarimono;
    $config->{kousinji} = time();

    # ddc/ndc更新
    my $ndc_query = "select left(ndc, 1) as ndcl1, count(*) as count from sakuhin where ndc is not null and ndc <> '' and ndc <> '726.1' and (yotei <> 1 or yotei is null) group by ndcl1";
    $config->{hantyuu}{jyouhou}{total}{ndc} = 0;
	my $ndc_syutoku = $dbh->prepare($ndc_query);
	$ndc_syutoku->execute();
	while(my $v = $ndc_syutoku->fetchrow_hashref){
        $config->{ndc}{$v->{ndcl1}} = $v->{count};
        $config->{hantyuu}{jyouhou}{total}{ndc} = $config->{hantyuu}{jyouhou}{total}{ndc} + $v->{count};
	}

    my $ndc2_query = "select right(left(ndc, 2),1) as ndcl2, left(ndc, 1) as ndcl1, count(*) as count from sakuhin where ndc is not null and ndc <> '' and ndc <> '726.1' and yotei <> 1 group by ndcl1, ndcl2";
    $config->{ndc2} = undef;
	my $ndc2_syutoku = $dbh->prepare($ndc2_query);
	$ndc2_syutoku->execute();
	while(my $v = $ndc2_syutoku->fetchrow_hashref){
        $config->{ndc2}{$v->{ndcl1}}{$v->{ndcl2}} = $v->{count};
	}

    # ddcで同じ処理仕方
    my $ddc_query = "select left(ddc, 1) as ddcl1, count(*) as count from sakuhin where ddc is not null and ddc <> '' and ndc <> '726.1' and (yotei <> 1 or yotei is null) group by ddcl1";
    $config->{hantyuu}{jyouhou}{total}{ddc} = 0;
	my $ddc_syutoku = $dbh->prepare($ddc_query);
	$ddc_syutoku->execute();
	while(my $v = $ddc_syutoku->fetchrow_hashref){
        $config->{ddc}{$v->{ddcl1}} = $v->{count};
        $config->{hantyuu}{jyouhou}{total}{ddc} = $config->{hantyuu}{jyouhou}{total}{ddc} + $v->{count};
	}

    my $ddc2_query = "select right(left(ddc, 2),1) as ddcl2, left(ddc, 1) as ddcl1, count(*) as count from sakuhin where ddc is not null and ddc <> '' and ddc not like '741.5%' and yotei <> 1 group by ddcl1, ddcl2";
    $config->{ddc2} = undef;
	my $ddc2_syutoku = $dbh->prepare($ddc2_query);
	$ddc2_syutoku->execute();
	while(my $v = $ddc2_syutoku->fetchrow_hashref){
        $config->{ddc2}{$v->{ddcl1}}{$v->{ddcl2}} = $v->{count};
	}
    
    #ソート
    #映画用：select replace(substr(substring_index(colle, 'gengo_',  -1), 1, 3), ',', '') as 'gengo', count(*) as count from sakuhin where hantyuu = 9 and (yotei <> 1 or yotei is null) group by gengo
    my $drama_nendai_query = "select substr(substring_index(colle, 'drama',  -1), 1, 2) as 'drama', count(*) as count from sakuhin where hantyuu = 10 and (yotei <> 1 or yotei is null) group by drama";
    my $drama_nendai_syutoku = $dbh->prepare($drama_nendai_query);
	$drama_nendai_syutoku->execute();
	while(my $v = $drama_nendai_syutoku->fetchrow_hashref){
        $config->{hantyuu}{jyouhou}{drama}{$v->{drama}} = $v->{count} if looks_like_number($v->{drama});
	}
    my $comic_nendai_query = "select substr(substring_index(colle, 'comic',  -1), 1, 2) as 'comic', count(*) as count from sakuhin where hantyuu = 13 and (yotei <> 1 or yotei is null) group by comic";
    $config->{hantyuu}{jyouhou}{total}{comic} = 0;
    my $comic_nendai_syutoku = $dbh->prepare($comic_nendai_query);
	$comic_nendai_syutoku->execute();
	while(my $v = $comic_nendai_syutoku->fetchrow_hashref){
        $config->{hantyuu}{jyouhou}{comic}{$v->{comic}} = $v->{count} if looks_like_number($v->{comic});
        $config->{hantyuu}{jyouhou}{total}{comic} = $config->{hantyuu}{jyouhou}{total}{comic} + $v->{count} if looks_like_number($v->{comic});
	}
    my $anime_nendai_query = "select substr(substring_index(colle, 'anime',  -1), 1, 2) as 'anime', count(*) as count from sakuhin where hantyuu = 14 and (yotei <> 1 or yotei is null) group by anime";
    $config->{hantyuu}{jyouhou}{total}{anime} = 0;
    my $anime_nendai_syutoku = $dbh->prepare($anime_nendai_query);
	$anime_nendai_syutoku->execute();
	while(my $v = $anime_nendai_syutoku->fetchrow_hashref){
        $config->{hantyuu}{jyouhou}{anime}{$v->{anime}} = $v->{count} if looks_like_number($v->{anime});
        $config->{hantyuu}{jyouhou}{total}{anime} = $config->{hantyuu}{jyouhou}{total}{anime} + $v->{count} if looks_like_number($v->{anime});
	}
    my $eiga_nendai_query = "select replace(replace(substr(substring_index(colle, 'movie',  -1), 1, 4), 's', ''), ',', '') as 'movie', count(*) as count from sakuhin where hantyuu = 9 and (yotei <> 1 or yotei is null) group by movie";
    $config->{hantyuu}{jyouhou}{total}{movie} = 0;
    my $eiga_nendai_syutoku = $dbh->prepare($eiga_nendai_query);
	$eiga_nendai_syutoku->execute();
	while(my $v = $eiga_nendai_syutoku->fetchrow_hashref){
        $config->{hantyuu}{jyouhou}{movie}{$v->{movie}} = $v->{count} if looks_like_number(substr($v->{movie}, 0, 2));
        $config->{hantyuu}{jyouhou}{total}{movie} = $config->{hantyuu}{jyouhou}{total}{movie} + $v->{count} if looks_like_number($v->{movie});
	}
    my $hantyuu_count_query = "select saku.hantyuu, count(*) as count, kei from sakuhin saku join hantyuu han on saku.hantyuu = han.orig_id where (yotei <> 1 or yotei is null) group by saku.hantyuu";
    my $hantyuu_count_syutoku = $dbh->prepare($hantyuu_count_query);
	$hantyuu_count_syutoku->execute();
    $config->{hantyuu}{jyouhou}{total}{51} = 0;
    $config->{hantyuu}{jyouhou}{total}{52} = 0;
    $config->{hantyuu}{jyouhou}{total}{53} = 0;
    $config->{hantyuu}{jyouhou}{total}{total} = 0;
	while(my $v = $hantyuu_count_syutoku->fetchrow_hashref){
        $config->{hantyuu}{jyouhou}{total}{$v->{hantyuu}} = $v->{count};
        $config->{hantyuu}{jyouhou}{total}{$v->{kei}} = $config->{hantyuu}{jyouhou}{total}{$v->{kei}} + $v->{count};
        $config->{hantyuu}{jyouhou}{total}{total} = $config->{hantyuu}{jyouhou}{total}{total} + $v->{count};
	}
    my $waku_count_query = "select turu, midasi_seisiki, sort1 from collection where tag in ('waku', 'wakuame', 'kyoku')";
    my $waku_count_syutoku = $dbh->prepare($waku_count_query);
    $waku_count_syutoku->execute();
    my ($m, $waku_id);
    $m = 0;

    $config->{hantyuu}{jyouhou}{total}{waku} = undef;
    while(my $v = $waku_count_syutoku->fetchrow_hashref){
        my @turu = split ',', $v->{turu};
        my $turu_sitazi;
        for(my $i=0; $i<scalar(@turu); $i++){ $turu_sitazi .= '?, ' }
        $turu_sitazi =~ s/,\s*$//; #　後端のコンマを削除す
        my $yotei_kakunin_query = "select id from sakuhin where (yotei <> 1 or yotei is null) and `id` in ($turu_sitazi) and colle like '%$v->{midasi_seisiki}%'";
        my $yotei_kakunin_syutoku = $dbh->prepare($yotei_kakunin_query);
        $yotei_kakunin_syutoku->execute(@turu);
        $waku_id->{$v->{sort1}} = defined $waku_id->{$v->{sort1}} ? $waku_id->{$v->{sort1}} : ($waku_id ? (scalar keys %{$waku_id}) : 0);
        my $turu_syorizumi = $yotei_kakunin_syutoku->fetchall_arrayref();
        $config->{hantyuu}{jyouhou}{total}{waku}[$waku_id->{$v->{sort1}}] = {
            "namae" => $v->{sort1},
            "count" => $config->{hantyuu}{jyouhou}{total}{waku}[$waku_id->{$v->{sort1}}]{count} + scalar(@$turu_syorizumi)
        };
        $config->{hantyuu}{jyouhou}{waku}{$v->{sort1}}{$v->{midasi_seisiki}} = scalar(@$turu_syorizumi);
        $m++;
    }

    #書き出す
    config_kousin($config);
}

if(defined param('kyousei') && param('kyousei') eq '1'){
    my $query=new CGI;
    print $query->redirect($ENV{HTTP_REFERER});
    print "Content-type: text/html; charset=utf-8\n\n";
}