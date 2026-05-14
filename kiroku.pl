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
use Scalar::Util qw( looks_like_number );

use Kahifu::Junbi;
use Kahifu::Template qw{dict};
use Kahifu::Setuzoku;
use Hyouka::Infra qw(jyoukyou_settei midasi_settei sakka_settei date date_split url_get_tuke url_get_hazusi week week_border week_count week_delta hash_max_key timestamp_syutoku);
use Hyouka::External;

#print "Content-type: text/html; charset=utf-8\n\n";

if(request_method eq 'POST' && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');

	my $midasi = defined param('midasi') && param('midasi') ? decode_utf8(param('midasi')) : "";
	my $fukumidasi = defined param('fukumidasi') && param('fukumidasi') ? decode_utf8(param('fukumidasi')) : "";
	my $hantyuu_raw = defined param('hantyuu') && param('hantyuu') ? decode_utf8(param('hantyuu')) : "";
	my $sakka = defined param('sakka') && param('sakka') ? decode_utf8(param('sakka')) : "";
	my $genkan = defined param('genkan') && param('genkan') ? decode_utf8(param('genkan')) : undef;	
	my $colle = defined param('colle') && param('colle') ? decode_utf8(param('colle')) : "";	
	my $bikou = defined param('bikou') && param('bikou') ? decode_utf8(param('bikou')) : "";	
	my $cour = defined param('cour') && param('cour') ? decode_utf8(param('cour')) : undef;		
	my $whole = defined param('whole') && param('whole') ? decode_utf8(param('whole')) : "";		
	my $josuu = defined param('josuu') && param('josuu') ? decode_utf8(param('josuu')) : "";		
	my $mikakutei = defined param('mikakutei') && param('mikakutei') ? decode_utf8(param('mikakutei')) : 0;		
	my $kansyouzumi = defined param('kansyouzumi') && param('kansyouzumi') ? decode_utf8(param('kansyouzumi')) : 0;	
	my $yotei = defined param('yotei') && param('yotei') && $kansyouzumi == 0 ? decode_utf8(param('yotei')) : 0;		
	
	my $genzai = time();
	my $kaisi = defined param('kaisi') && param('kaisi') ? decode_utf8(param('kaisi')) : undef;	
	my $syuuryou = defined param('syuuryou') && param('syuuryou') ? decode_utf8(param('syuuryou')) : undef;
	my ($cour_year) = $cour =~ m/\d{1,4}/g;
	my $cour_season;
	$cour_season = "冬" if index(lc($cour), "冬") != -1 || index(lc($cour), "w") != -1;
	$cour_season = "春" if index(lc($cour), "春") != -1 ||index(lc($cour), "sp") != -1;
	$cour_season = "夏" if index(lc($cour), "夏") != -1 ||index(lc($cour), "su") != -1;
	$cour_season = "秋" if index(lc($cour), "秋") != -1 ||index(lc($cour), "f") != -1 || index(lc($cour), "a") != -1;
	$cour = $cour_year.$cour_season ne "" ? $cour_year.$cour_season : undef;

	my $hantyuu_get_query = "select hantyuu from hantyuu_alias where kotoba = ?";
	my $hantyuu_get = $dbh->prepare($hantyuu_get_query);
	$hantyuu_get->execute($hantyuu_raw);
	my $hantyuu;
	while(my $v = $hantyuu_get->fetchrow_arrayref){
		$hantyuu = $v->[0];
	}

	$cour = cour($syuuryou, $hantyuu) if defined $syuuryou && !defined $cour;
	my $cour_bikou = substr($cour, 0, 4) . '年' . substr($cour, 4);
	my $period_jiten = {
		'10' => 'drama',
		'14' => 'anime',
		'17' => 'anime',
		'13' => 'comic',
		'9' => 'movie'
	};

	if((index($colle, 'kansyou') == -1 || index($colle, 'gengo') == -1) && defined $genkan){
		my $kugiri_hituyou = $colle =~ tr/,//;
		$kugiri_hituyou = 2 + (2 * $kugiri_hituyou);
		my $bikou_kugiri_count = $bikou =~ tr/+//;
		my $bikou_kugiri_hituyou = $kugiri_hituyou - $bikou_kugiri_count;
		$bikou .= '+' x $bikou_kugiri_hituyou;

		$colle .= "," if substr($colle, -1) ne ',' && $colle ne '';

		my @genkan_turu = split '/', $genkan;
		my $double;
		if(defined $genkan_turu[0] && $genkan_turu[0] ne ''){
			$colle .= "gengo_" . $genkan_turu[0];
			$bikou .= "++";
			$double = 1;
		}
		$colle .= "," if $double;
		if(defined $genkan_turu[1] && $genkan_turu[1] ne ''){
			$colle .= "kansyou_" . $genkan_turu[1];
			$bikou .= "++";
		} elsif (defined $genkan_turu[0] && $genkan_turu[0] ne '' && index($genkan, '/') == -1){
			$colle .= "kansyou_" . $genkan_turu[0];
			$bikou .= "++";
		}
	}

	if(index($colle, $period_jiten->{$hantyuu}) == -1 || (index($colle, $period_jiten->{$hantyuu}) != -1 && looks_like_number(substr($colle, index($colle, $period_jiten->{$hantyuu})+5, 2)) != 1)){
		my $tosi = substr($kaisi, 0, 4);
		$tosi = $tosi + 0;
		my $period = $tosi < 1930 || ($hantyuu == 9 && $tosi >= 2030) ? substr($tosi, 0, 3) . '0s' : substr($tosi, 2, 1) . '0s';

		my $kugiri_hituyou = $colle =~ tr/,//;
		$kugiri_hituyou = 2 + (2 * $kugiri_hituyou);
		my $bikou_kugiri_count = $bikou =~ tr/+//;
		my $bikou_kugiri_hituyou = $kugiri_hituyou - $bikou_kugiri_count;
		$bikou .= '+' x $bikou_kugiri_hituyou;

		$colle .= "," if substr($colle, -1) ne ',' && $colle ne '';

		$colle .= $period_jiten->{$hantyuu} . $period;
		my $wafuu_tosi = substr($kaisi, 0, 4);
		my $wafuu_tuki = substr($kaisi, 4, 2);
		my $wafuu_hi = substr($kaisi, 6, 2);
		$wafuu_tuki = substr($wafuu_tuki, 0) eq '0' && $wafuu_tuki ne '' ? substr($wafuu_tuki, 1, 1) . '月' : $wafuu_tuki . '月';
		$wafuu_hi = substr($wafuu_hi, 0) eq '0' && $wafuu_hi ne '' ? substr($wafuu_hi, 1, 1) . '日' : $wafuu_hi . '日';
		my $wafuu_hiduke = $wafuu_tosi . '年' . $wafuu_tuki . $wafuu_hi;
		$bikou .= $wafuu_hiduke . "++";
	}
	
	my @colle_list_get = $dbh->selectall_array("select midasi_seisiki from collection");
	for(my $i=0; $i<scalar(@colle_list_get); $i++){$colle_list_get[$i] = $colle_list_get[$i][0]}
	my @colle_try = split(',', $colle);

	my %to_delete = map { $_ => 1 } @colle_list_get;
	@colle_try = grep { $to_delete{$_} } @colle_try;
	my $colle_turu = join(',', @colle_try);
	my $colle_turu_sitazi = scalar @colle_try > 0 ? ", colle = ?" : "";
	
	#print dump @colle_try;

	my @bikou_split = split('\+\+', $bikou) if $bikou;

	my ($al_id, $mal_id, $tmdb_id);
	my $api_json_data = Hyouka::External::api_json_syutoku();
	if((grep{$_ eq $hantyuu} 13, 14, 17) && index($colle_turu, "gengo_ja") != -1){
		$al_id = $hantyuu == 13 ? Hyouka::External::al_manga_kensaku($midasi, $api_json_data) : Hyouka::External::al_anime_kensaku($midasi, $api_json_data);
		$mal_id = $hantyuu == 13 ? Hyouka::External::mal_manga_kensaku($midasi, $api_json_data) : Hyouka::External::mal_anime_kensaku($midasi, $api_json_data);
		if($kansyouzumi == 1){
			Hyouka::External::mal_kousin($mal_id, $whole, $josuu, '終', 0, 700000, $hantyuu, $api_json_data) if defined $mal_id && $mal_id ne '';
			Hyouka::External::al_kousin($al_id, $whole, $josuu, '終', 0, undef, 700000, $api_json_data) if defined $al_id && $al_id ne '';
		} else {
			Hyouka::External::mal_kousin($mal_id, 0, $josuu, '未', 0, 700000, $hantyuu, $api_json_data) if defined $mal_id && $mal_id ne '';
			Hyouka::External::al_kousin($al_id, 0, $josuu, '未', 0, undef, 700000, $api_json_data) if defined $al_id && $al_id ne '';
		}
	}
	if(grep{$_ eq $hantyuu} 9, 10, 17){
		my $mode = $hantyuu == 10 ? 2 : 0;
		$tmdb_id = Hyouka::External::tmdb_kensaku($midasi, $mode, $api_json_data);
	}
	
	my $meirei = "insert into sakuhin set yotei = ?, mal_id = ?, al_id = ?, tmdb_id = ?, midasi = ?, fukumidasi = ?, time = ?, hantyuu = ?, cour = ?, sakka = ?, hajimari = ?, owari = ?, josuu = ?, part = ?, whole = ?, jyoukyou = ?, kaisi = ?, syuuryou = ?, mikakutei = ? ${colle_turu_sitazi}";
	
	my $hajimari = param('tosi_hajimari').param('tuki_hajimari').param('hi_hajimari').param('ji_hajimari').param('fun_hajimari') ne "" ? timestamp_syutoku(param('tosi_hajimari'), param('tuki_hajimari'), param('hi_hajimari'), param('ji_hajimari'), param('fun_hajimari')) : (param('unix_hajimari') ne '' ? param('unix_hajimari') : time());
	my $owari = $hajimari;
	my $part = ($kansyouzumi == 1) ? $whole : 0;
	my $jyoukyou = ($kansyouzumi == 1) ? '終' : '';
	
	my $sakuhin_insert = $dbh->prepare($meirei);
	$sakuhin_insert->execute($yotei, $mal_id, $al_id, $tmdb_id, $midasi, $fukumidasi, $genzai, $hantyuu, $cour, $sakka, $hajimari, $owari, $josuu, $part, $whole, $jyoukyou, $kaisi, $syuuryou, $mikakutei, $colle_turu);
	my $id = $dbh->{mysql_insertid};
	
	if($kansyouzumi == 1){
		my $rireki_sousin_query = "insert into rireki (`sid`, `jiten`, `part`, `whole`, `jyoukyou`, `josuu`, `mkt`) values (?, ?, ?, ?, ?, ?, ?)";
		my $rireki_sousin = $dbh->prepare($rireki_sousin_query);
		$rireki_sousin->execute($id, $owari, $whole, $whole, $jyoukyou, $josuu, $mikakutei);
	}
	
	my $key = 0;
	for my $i (@colle_try){
		my $read_bikou;
		my $read_tag;
		my $bikou_sitazi;
		my @sitazi_bind;
		my $unserial_bikou;
		if($bikou){
			my $bikou_get_query = "select bikou, tag from collection where midasi_seisiki = ?";
			my $bikou_get = $dbh->prepare($bikou_get_query);
			$bikou_get->execute($i);
			while(my $v = $bikou_get->fetchrow_arrayref){
				$read_bikou = $v->[0];
				$read_tag = $v->[1]; 
			}
			$unserial_bikou = from_json($read_bikou);
			$unserial_bikou->{$id} = $read_tag eq 'waku' && $bikou_split[$key] eq '' ? $cour_bikou : $bikou_split[$key];
		}	
		
		if($bikou){
			$bikou_sitazi = ", `bikou` = ?";
			my $serial_bikou = to_json($unserial_bikou);
			push @sitazi_bind, ($serial_bikou);
		}
		my $read_turu;
		my $turu_get_query = "select turu from collection where midasi_seisiki = ?";
		my $turu_get = $dbh->prepare($turu_get_query);
		$turu_get->execute($i);
		while(my $v = $turu_get->fetchrow_arrayref){
			$read_turu = $v->[0];
		}
		my @maki = split(',', $read_turu);
		push @maki, $id;
		my $turu_new = join(',', @maki);
		# `turu` = concat(ifnull(`turu`,''), ?) ←更新する場合
		my $colle_settei = "update collection set `turu` = ? ${bikou_sitazi} where `midasi_seisiki` = ?";
		my $colle_send = $dbh->prepare($colle_settei);
		$colle_send->execute($turu_new, @sitazi_bind, $i);
		
		$key++;
	}	
}

my $query=new CGI;
print $query->redirect($ENV{HTTP_REFERER});
print "Content-type: text/html; charset=utf-8\n\n";