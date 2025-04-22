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
use Digest::SHA qw( sha256 );

use Kahifu::Junbi;
use Kahifu::Template qw{dict};
use Kahifu::Setuzoku;
use Kahifu::Key;
use Hyouka::Infra qw(jyoukyou_settei midasi_settei sakka_settei date date_split url_get_tuke url_get_hazusi week week_border week_count week_delta hash_max_key color_makase image_makase);

my $uri = Kahifu::Template::fetch_uri(__FILE__);
my $ami = Kahifu::Template::fetch_ami($uri);

my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
my %cookie = CGI::Cookie->fetch;
my $query = CGI->new;
my @title_post = $query->param;
my %url_get = $query->Vars();

if (request_method eq 'POST'){
	my $cookie_siborikomi_hantyuu = Kahifu::Infra::cookie_seisei('hyouka_siborikomi_hantyuu', param('page_siborikomi_hantyuu'));
	print "Set-Cookie: $cookie_siborikomi_hantyuu\n" if defined param('page_siborikomi_hantyuu');
	my $cookie_siborikomi_jyoukyou = Kahifu::Infra::cookie_seisei('hyouka_siborikomi_jyoukyou', param('page_siborikomi_jyoukyou'));
	print "Set-Cookie: $cookie_siborikomi_jyoukyou\n" if defined param('page_siborikomi_jyoukyou');
	my $cookie_narabi = Kahifu::Infra::cookie_seisei('hyouka_narabi', param('narabi'));
	print "Set-Cookie: $cookie_narabi\n" if defined param('narabi');
	my $cookie_jun = Kahifu::Infra::cookie_seisei('hyouka_jun', param('jun'));
	print "Set-Cookie: $cookie_jun\n" if defined param('jun');
	my $query=new CGI;
	
	delete($url_get{narabikae_kettei});
	delete($url_get{page_siborikomi_hantyuu});
	delete($url_get{page_siborikomi_jyoukyou});
	delete($url_get{narabi});
	delete($url_get{jun});
	
	if(defined param('paginate')){
		my $cookie_paginate_colle = Kahifu::Infra::cookie_seisei('hyouka_paginate', 1);
		print "Set-Cookie: $cookie_paginate_colle\n";
		delete($url_get{paginate});
		$uri = url_get_hazusi(\%url_get, 'paginate');
	} elsif(defined param('favorite')){
		my $cookie_paginate_colle = Kahifu::Infra::cookie_seisei('hyouka_paginate', 2);
		print "Set-Cookie: $cookie_paginate_colle\n";
		delete($url_get{favorite});
		$uri = url_get_hazusi(\%url_get, 'favorite');
	} elsif(defined param('rireki')){
		my $cookie_paginate_colle = Kahifu::Infra::cookie_seisei('hyouka_paginate', 3);
		print "Set-Cookie: $cookie_paginate_colle\n";
		delete($url_get{rireki});
		$uri = url_get_hazusi(\%url_get, 'rireki');
	}
	
	if(defined param('narabikae_kettei')){
		$uri = url_get_tuke(\%url_get, 'kensaku', decode_utf8(param('kensaku'))) if defined param('kensaku') && param('kensaku') ne '';
	} elsif (defined param('kaijyo')){
		delete($url_get{kaijyo});
		$uri = url_get_hazusi(\%url_get, 'kensaku');
	}
	print $query->redirect($uri);
}
our $ninsyou = (defined $cookie{kangeiroku_ninsyou} && unpack('H*', sha256($cookie{kangeiroku_ninsyou})) == Kahifu::Key::hyouka_sesame) || Kahifu::Template::tenmei;

our $style = (defined $cookie{hyouka_style}) ? $cookie{hyouka_style}->value : 'gokusaisiki';
our $narabi = (defined $cookie{hyouka_narabi}) ? $cookie{hyouka_narabi}->value : 1;
our $jun = (defined $cookie{hyouka_jun}) ? $cookie{hyouka_jun}->value : 0;
our $siborikomi_hantyuu = (defined $cookie{hyouka_siborikomi_hantyuu}) ? $cookie{hyouka_siborikomi_hantyuu}->value : 50;
our $siborikomi_jyoukyou = (defined $cookie{hyouka_siborikomi_jyoukyou}) ? $cookie{hyouka_siborikomi_jyoukyou}->value : 1;
our $paginate = (defined $cookie{hyouka_paginate}) ? $cookie{hyouka_paginate}->value : 1;
our $page = (defined param('page') && param('page') != 1 && $ninsyou) ? param('page') : 1;
our $page_offset = ($page != 1) ? 20 * (param('page')-1) : 0;
our $week = (defined param('week') && param('week') != 0 && $ninsyou) ? param('week') : 0;

my $imagenzai = time();

print "Content-type: text/html; charset=utf-8\n\n";

print Kahifu::Template::html_header($ami);
print "<link rel=\"stylesheet\" href=\"/chronicle/style/sumi.css\" />";
print "<link rel=\"stylesheet\" href=\"/chronicle/style/";
print $style;
print ".css\" />";
print "<link rel=\"stylesheet\" href=\"/chronicle/style/keitai.css\" />" if Kahifu::Infra::mobile();
print "<script src='/heart/js/Sortable.min.js'></script>" if defined param('hensyuu') && $paginate == 2;
print "<script src='/heart/js/jquery-sortable.js'></script>" if defined param('hensyuu') && $paginate == 2;
print Kahifu::Template::html_saki("${\(Kahifu::Template::dict('HYOUKA_TITLE'))}<span>${\(Kahifu::Template::dict('EIGOYOU_KUUHAKU'))}${\(Kahifu::Template::dict('HYOUKA_SUBTITLE'))}</span>");

# html>enter 
#print @title_post;
#
#　さくひんの中
#　タグ、履歴、関連人物、なが感想などなど
#
#
if(defined param('id') && param('id')){
	my $sakuhin_query = "select * from sakuhin where id = ?";
	my $sakuhin_syutoku = $dbh->prepare($sakuhin_query);
	my $passthrough_id = param('id');
	$sakuhin_syutoku->execute($passthrough_id);
	my $sakuhin_info = $sakuhin_syutoku->fetchall_hashref('id');
	my @sakuhin_colle = split ',', $sakuhin_info->{$passthrough_id}{colle};
	my $colle_placeholders = join ", ", ("?") x @sakuhin_colle;
	my $seed = $sakuhin_info->{$passthrough_id}{time};
	print "<div class='sakuhinbako' style=\"background-image: url('${\(image_makase('flower/png', $seed+1))}')\">";
		print "<div class='hidari' style=\"background-image: url('${\(image_makase('flower/png', $seed))}')\">";
			print "<a class='modoru' href='${\(url_get_hazusi(\%url_get, 'id'))}'>${\(Kahifu::Template::dict('MODORU'))}</a>";
			print "<div class='heading'>$sakuhin_info->{$passthrough_id}{midasi}</div>";
			print "<div class='subheading'>$sakuhin_info->{$passthrough_id}{fukumidasi}</div>";
			print "<div class='sakka'>$sakuhin_info->{$passthrough_id}{sakka}</div>";
			print "<div class='bunsyou'>";
			my $kansou_query = "select * from kansou_long where sid = ?";
			my $kansou_syutoku = $dbh->prepare($kansou_query);
			$kansou_syutoku->execute($passthrough_id);
			my $kansou_info = $kansou_syutoku->fetchall_hashref('sid');
			print Kahifu::Infra::bunsyou($kansou_info->{$passthrough_id}{kansou}) if defined $kansou_info->{$passthrough_id}{kansou};
			print "</div>";
			print "<div data-kakejiku='kansou_long' class='kakejiku'><span>${\(Kahifu::Template::dict('KANSOU_HENSYUU_DESC'))}<span class='sinsyuku'>＋</span></span></div>" if Kahifu::Template::tenmei;
			print "<form method='post' id='sakunai_kansou' action='sakunai.pl'><input type='hidden' name='reference' value='${passthrough_id}'><div data-kakejiku='kansou_long'><textarea name='text' form='sakunai_kansou'>", $kansou_info->{$passthrough_id}{kansou}//'', "</textarea><input name='kansou_sousin' type='submit' value='${\(Kahifu::Template::dict('SOUSIN'))}'></div></form>";
			print "<div data-kakejiku='ten' class='kakejiku'><span>点数<span class='sinsyuku'>${\(Kahifu::Template::dict('SINSYUKU_PLUS'))}</span></span></div>" if Kahifu::Template::tenmei;
			print "<form method='post' id='sakunai_tennsuu' action='tensuu.pl'><input type='hidden' name='reference' value='${passthrough_id}'><div data-kakejiku='ten'><input name='tensuu_kojin' placeholder='私式→", $sakuhin_info->{passthrough_id}{point}//'', "' value='", $sakuhin_info->{$passthrough_id}{point}//'', "'><input name='tensuu_mal_pt' placeholder='ﾏｲｱﾆ→", $sakuhin_info->{$passthrough_id}{mal_pt}//'', "／10' value='", $sakuhin_info->{$passthrough_id}{mal_pt}//'', "'><input name='tensuu_al_pt' placeholder='ｱﾆﾘｽﾄ→", $sakuhin_info->{passthrough_id}{al_pt}//'', "／100' value='", $sakuhin_info->{$passthrough_id}{al_pt}//'', "'><input name='tensuu_bl_pt' placeholder='ﾌﾞｸﾛｸﾞ→", $sakuhin_info->{passthrough_id}{bl_pt}//'', "／10' value='", $sakuhin_info->{$passthrough_id}{bl_pt}//'', "'><input name='tensuu_sousin' type='submit' value='送信'></div></form>";
		print "</div>";
		print "<div class='migi'>";
			print "<div class='tensuu'>", $sakuhin_info->{$passthrough_id}{point}, "点</div>" if defined $sakuhin_info->{$passthrough_id}{point};
			my $collection_query = "select * from collection where midasi_seisiki in ($colle_placeholders)";
			my $collection_syutoku = $dbh->prepare($collection_query);
			$collection_syutoku->execute(@sakuhin_colle);
			while(my $v = $collection_syutoku->fetchrow_hashref){
				my $colle_seed = $v->{jiten} + 2;
				print "<div style='background-color: hsl(${\(color_makase($colle_seed))}, 60%, 88%)' class='colle'>";
					print "<a href='${\(url_get_tuke(\%url_get, 'collection', $v->{id}))}'>";
					print $v->{midasi};
					print "</a>";
					print my $sakuhin_bikou = ${\( sub { return "<div class='$v->{tag}'>" . from_json($v->{bikou})->{param('id')} . "</div>" if ref(from_json($v->{bikou})) ne 'ARRAY' && defined from_json($v->{bikou})->{param('id')} }->() )} if defined $v->{bikou} && $v->{bikou} ne '';
				print "</div>";
			}
		print "</div>";
	print "</div>";
	
	print Kahifu::Template::html_noti();
	exit;
}

# 
#　カタログ一覧
#　カタログ、履歴、蒐集などなど
#
#
my ($kensaku, $kensaku_sitazi, $gyaku_kensaku_sitazi, $hantyuu_sibori_sitazi, $jyoukyou_sibori_sitazi, $narabikae_sitazi, $jun_sitazi, @sitazi_bind, @sitazi_bind_2);
$gyaku_kensaku_sitazi = "(`yotei` <> 1 or `yotei` is null) and ";
if (defined param('kensaku') && param('kensaku')){
	$kensaku = "${\(decode_utf8(param('kensaku')))}";
	$kensaku_sitazi = "and (`midasi` like ? or `fukumidasi` like ? or `sakka` like ?)";
	$gyaku_kensaku_sitazi = "";
	push @sitazi_bind, ("%${kensaku}%", "%${kensaku}%", "%${kensaku}%");
	push @sitazi_bind_2, ("%${kensaku}%", "%${kensaku}%", "%${kensaku}%") if $page == 1;	
} else { $kensaku_sitazi = ""; }
if (defined $siborikomi_hantyuu && $siborikomi_hantyuu && $siborikomi_hantyuu ne '50'){ 
	$hantyuu_sibori_sitazi = "and (`hantyuu` in (?))";
	push @sitazi_bind, ($siborikomi_hantyuu);
	push @sitazi_bind_2, ($siborikomi_hantyuu) if $page == 1;
} else { $hantyuu_sibori_sitazi = ""; }
if (defined $siborikomi_jyoukyou && $siborikomi_jyoukyou && $siborikomi_jyoukyou ne '1'){ 
	$jyoukyou_sibori_sitazi = "and (`jyoukyou` in (?))";
	push @sitazi_bind, ("${\(Kahifu::Template::dict('HYOUKA_JYOUKYOU_' . ${\($siborikomi_jyoukyou)}))}");
	push @sitazi_bind_2, ("${\(Kahifu::Template::dict('HYOUKA_JYOUKYOU_' . ${\($siborikomi_jyoukyou)}))}") if $page == 1;
} else { $jyoukyou_sibori_sitazi = ""; }
my @narabi_henkan = ('`owari`', '`hajimari`', '`time`', '`point`');
my @jun_henkan = ('desc', 'asc');
my $narabi_tuuka = (defined $narabi_henkan[$narabi-1]) ? $narabi_henkan[$narabi-1] : $narabi_henkan[0];
my $jun_tuuka = (defined $jun_henkan[$jun]) ? $jun_henkan[$jun] : $jun_henkan[0];
my $junni_tuuka = ($jun == 0) ? 'asc' : 'desc';

# paginateの準備をする
my @josuu_tati = $dbh->selectall_array("select `josuu` from `josuu`");
my @sizi_tati = $dbh->selectall_array("select `sizi` from `josuu_sizi`");
my ($current_turu, @r, @current_list, $row_count, $page_saigo, $meirei_presitami, $meirei_sitami, $count_sitami, $page_subete);
my ($kansyou_current_rows, $kansyou_all_rows);
my (@hantyuu_type, @hantyuu_data, @hantyuu_class, %jyoukyou_type, %jyoukyou_class, @jyoukyou_name);
my (@meirei, @daimei);
#　paginate=3の
my (@week_border_original, $week_limit_lower, $week_limit_upper, $koyomi_week_count, $dst_musi_week_limit_lower);
my (@rireki_sakuhin, @rireki_count);
my ($hantyuu_syutoku, %koyomi_hantyuu_winner);
my ($rirekiran);
if($paginate == 1){
	#　最初のページの行数を数える（鑑賞中＋鑑賞ずみ）
	$meirei_presitami = $dbh->prepare("select `id` from `sakuhin` where ${gyaku_kensaku_sitazi} (`jyoukyou` = '中' or `jyoukyou` = '再' or `current` = 1) and (`current` is null or `current` != 2) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi}");
	$meirei_presitami->execute();
	$kansyou_current_rows = $meirei_presitami->rows();
	# $row_count = ($page == 1) ? $kansyou_current_rows + 20 : 20;
	$row_count = 20;
	#　idたちを集める
	# 旧meirei: select `id` from `sakuhin` where ((!(`jyoukyou` = '中' or `jyoukyou` = '再') and (`current` is null or `current` != 1)) or ((`jyoukyou` = '中' or `jyoukyou` = '再') and `current` = 2))||(((`jyoukyou` = '中' or `jyoukyou` = '再' or (`current` = 1)) and (`current` is null or `current` != 2))) order by `owari` desc limit ${row_count} offset ?
	$meirei_sitami = ($page == 1) ? $dbh->prepare("select * from 
		(select `id`, `owari` from `sakuhin` where ${gyaku_kensaku_sitazi} (((`jyoukyou` = '中' or `jyoukyou` = '再' or (`current` = 1)) and (`current` is null or `current` != 2))) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi}) a union select * from (select `id`, `owari` from `sakuhin` where ${gyaku_kensaku_sitazi} (!(`jyoukyou` = '中' or `jyoukyou` = '再') and (`current` is null or `current` != 1)) or ((`jyoukyou` = '中' or `jyoukyou` = '再') and `current` = 2) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} order by `owari` desc limit ${row_count} offset ? ) b order by `owari` desc") : $dbh->prepare("select `id` from `sakuhin` where ${gyaku_kensaku_sitazi} ((!(`jyoukyou` = '中' or `jyoukyou` = '再') and (`current` is null or `current` != 1)) || ((`jyoukyou` = '中' or `jyoukyou` = '再') and `current` = 2)) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} order by ${narabi_tuuka} ${jun_tuuka}, `junni` ${junni_tuuka} limit ${row_count} offset ?");
	$page != 1 ? $meirei_sitami->execute(@sitazi_bind, $page_offset) : 	$meirei_sitami->execute(@sitazi_bind, @sitazi_bind_2, $page_offset);
	while(my $v = $meirei_sitami->fetchrow_hashref){
		push @current_list, $v->{id};	
	}
	$current_turu = join(',', @current_list);
	$current_turu = 0 if $current_turu eq '';
	@r = $dbh->selectall_array("select * from `rireki` where `sid` in ($current_turu)");
	#　クエリーに伴って全ての行数を数える
	$count_sitami = $dbh->prepare("select `id` from `sakuhin` where ${gyaku_kensaku_sitazi} (((!(`jyoukyou` = '中' or `jyoukyou` = '再') and (`current` is null or `current` != 1)) or ((`jyoukyou` = '中' or `jyoukyou` = '再') and `current` = 2))||(((`jyoukyou` = '中' or `jyoukyou` = '再' or (`current` = 1)) and (`current` is null or `current` != 2)))) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi}");
	$count_sitami->execute(@sitazi_bind);
	$kansyou_all_rows = $count_sitami->rows();
	$page_subete = ceil((($kansyou_all_rows - $kansyou_current_rows - 20) / 20) + 1);
	
	@meirei = ("select * from `sakuhin` where ${gyaku_kensaku_sitazi} ((`jyoukyou` = '中' or `jyoukyou` = '再' or (`current` = 1)) ${kensaku_sitazi} and (`current` is null or `current` != 2)) ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} order by `owari` desc", "select * from `sakuhin` where ${gyaku_kensaku_sitazi} ((!(`jyoukyou` = '中' or `jyoukyou` = '再') and (`current` is null or `current` != 1))||((`jyoukyou` = '中' or `jyoukyou` = '再') and `current` = 2)) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} order by ${narabi_tuuka} ${jun_tuuka}, `junni` ${junni_tuuka} limit 20 offset ?");
	@daimei = ("${\(Kahifu::Template::dict('TITLE_KANSYOUTYUU'))}", "${\(Kahifu::Template::dict('TITLE_KANSYOUZUMI'))}");
} elsif ($paginate == 3){
	# 暦を作るには…
	@week_border_original = week_border(${\(week($imagenzai))[0]}, ${\(week($imagenzai))[1]});
	$week_limit_lower = $week_border_original[0] - (($week - 0) * 604800); #lower = 古いの方
	$week_limit_upper = $week_border_original[0] - (($week - 1) * 604800); #upper = 新しいの方
	$dst_musi_week_limit_lower = ($week_border_original[0] - (($week - 0) * 604800)) + 3600;
	$koyomi_week_count = week_count(${\(week($dst_musi_week_limit_lower))[0]}) == 1 ? 52 : 53; # yr from yr,wk of weeklimlower to count
	#　part != 前のpart & jyou!=終（再開の場合を除く）	→週別（yearweek）で範疇の頻度を
	$hantyuu_syutoku = "select YEARWEEK(FROM_UNIXTIME(reki.`jiten`), 1) as `week`, `hantyuu`, count(*) as `count` from (SELECT (\@partpre = part AND \@sidpre=sid AND `jyoukyou` not in ('終','葉','中')) AS unchanged_status, rireki.*, \@partpre := part, \@sidpre := sid from rireki, (select \@partpre:=NULL, \@sidpre:=NULL) AS x order by sid, jiten) as reki left join sakuhin saku on reki.sid = saku.id where substring(YEARWEEK(FROM_UNIXTIME(reki.`jiten`), 1), 1, 4) = ? ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} and not unchanged_status group by `hantyuu`, `week` order by jiten desc";
	my $koyomi_hantyuu = $dbh->prepare($hantyuu_syutoku);
	$koyomi_hantyuu->execute(${\(week($dst_musi_week_limit_lower))[0]}, @sitazi_bind);
	while(my $v = $koyomi_hantyuu->fetchrow_hashref){
		my @hantyuu_inner_array = ($v->{week}, $v->{hantyuu}, $v->{count});		
		$koyomi_hantyuu_winner{$v->{week}} = \@hantyuu_inner_array if(defined $koyomi_hantyuu_winner{$v->{week}} && $v->{week} eq $koyomi_hantyuu_winner{$v->{week}}[0] && $koyomi_hantyuu_winner{$v->{week}}[2] < $v->{count} || not defined $koyomi_hantyuu_winner{$v->{week}});
	}
	
	@meirei = ("select reki.*, saku.midasi, saku.hantyuu, saku.kakusu from (select (\@partpre = part and \@sidpre=sid and `jyoukyou` not in ('終','葉','中')) as unchanged_status, rireki.*, \@partpre := part, \@sidpre := sid from rireki, (select \@partpre:=NULL, \@sidpre:=NULL) as x order by sid, jiten) as reki left join sakuhin saku on reki.sid = saku.id where not unchanged_status ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} and reki.jiten >= ? and reki.jiten <= ? order by jiten desc;", "select reki.jiten, saku.hantyuu from (select (\@partpre = part and \@sidpre=sid and `jyoukyou` not in ('終','葉','中')) as unchanged_status, rireki.*, \@partpre := part, \@sidpre := sid from rireki, (select \@partpre:=NULL, \@sidpre:=NULL) as x order by sid, jiten) as reki left join sakuhin saku on reki.sid = saku.id where not unchanged_status ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} and reki.jiten >= ? and reki.jiten <= ? order by jiten desc;");
}

print "<div class='commander'>";
	print "<div class='hidari'>";
		print "<div class='navi'>";
			if($paginate == 1){
				print "<a href='${\(url_get_tuke(\%url_get, 'page', ${\($page-1)}))}'>←</a>" if $page != 1;
				print "<span>";
				print "page ";
				print my $page = (defined param('page')) ? param('page') : 1;
				print "／";
				print $page_subete;
				print "</span>";
				print "<a class='migi' href='${\(url_get_tuke(\%url_get, 'page', ${\($page+1)}))}'>→</a>" if $page + 1 <= $page_subete;
			} elsif ($paginate == 2){
				print "<a href='${\(url_get_hazusi(\%url_get, 'collection'))}'>${\(Kahifu::Template::dict('MODORUZEYO'))}</a>" if defined param('collection');
				print "<span>${\(Kahifu::Template::dict('COLLECTION_HEADING'))}</span>" if not defined param('collection');
			} elsif ($paginate == 3){
				print "<a href='${\(url_get_tuke(\%url_get, 'week', ${\($week-1)}))}'>←</a>" if $week != 0;
				print "<span>${\(sub { return $week>0 ? \"第${week}週\" : \"${\(Kahifu::Template::dict('WEEK_TITLE_FIRST'))}\" }->())}${\(Kahifu::Template::dict('EIGOYOU_KUUHAKU'))}${\(Kahifu::Template::dict('NYORO'))}${\(week($dst_musi_week_limit_lower))[0]}${\(Kahifu::Template::dict('SUFFIX_TOSI'))}${\(Kahifu::Template::dict('EIGOYOU_KUUHAKU'))}${\(map { s/###/${\(week($dst_musi_week_limit_lower))[1]}/; $_ } do { ${\(Kahifu::Template::dict('WEEK_TITLE'))} }) }${\(Kahifu::Template::dict('NYORO'))}</span>";
				print "<a class='migi' href='${\(url_get_tuke(\%url_get, 'week', ${\($week+1)}))}'>→</a>" if $week + 1;
			}
		print "</div>";
		if($paginate != 3){
			print "<div class='hanrei'>";
				print "<span>${\(Kahifu::Template::dict('HYOUKA_STYLE'))}</span>";
				print "<div id='settei_sakura' data-style='stylesheet/sakura.css' class='theme sakura'>${\(Kahifu::Template::dict('HYOUKA_STYLE_1'))}</div>";
				print "<div id='settei_gokusaisiki' data-style='stylesheet/gokusaisiki.css' class='theme gokusaisiki'>${\(Kahifu::Template::dict('HYOUKA_STYLE_2'))}</div>";
			print "</div>";
			
			print "<div class='hanrei button'>";
				print "<span>${\(Kahifu::Template::dict('HYOUKA_HANTYUU'))}</span>";
				my $hantyuu_list = $dbh->prepare("select * from `hantyuu`");
				$hantyuu_list->execute();
				while(my $v = $hantyuu_list->fetchrow_hashref){
					print "<div data-nokori='$v->{hantyuu}' class='hantyuu_$v->{class}'>${\(Kahifu::Template::dict('HYOUKA_HANTYUU_' . $v->{orig_id}))}</div>";
					push @hantyuu_type, $v->{orig_id};
					push @hantyuu_data, $v->{hantyuu};
					push @hantyuu_class, $v->{class};
				}
			print "</div>";
			print "<div class='hanrei jyoukyou_itirann'>";
				print "<span>${\(Kahifu::Template::dict('HYOUKA_JYOUKYOU'))}</span>";
				my $jyoukyou_list = $dbh->prepare("select * from `jyoukyou`");
				$jyoukyou_list->execute();
				while(my $v = $jyoukyou_list->fetchrow_hashref){
					print "<div class='jyoukyou${\( sub { return ' all' if $v->{id}==1})->()}' data-name='$v->{jyoukyou}'><span class='jyoukyou_type_$v->{id} $v->{class}'>${\(Kahifu::Template::dict('HYOUKA_JYOUKYOU_' . $v->{id}))}</span></div>" if $v->{jyoukyou} ne "葉";
					print "<style>.jyoukyou_type_$v->{id} { color: hsla($v->{hsl}, 1); }</style>";
					$jyoukyou_type{$v->{jyoukyou}} = $v->{id};
					$jyoukyou_class{$v->{jyoukyou}} = $v->{class};
					push @jyoukyou_name, $v->{jyoukyou};
				}
			print "</div>";
		} elsif ($paginate == 3) {
			my $hantyuu_list = $dbh->prepare("select * from `hantyuu`");
			$hantyuu_list->execute();
			while(my $v = $hantyuu_list->fetchrow_hashref){
				push @hantyuu_type, $v->{orig_id};
				push @hantyuu_data, $v->{hantyuu};
				push @hantyuu_class, $v->{class};
			}
			my $jyoukyou_list = $dbh->prepare("select * from `jyoukyou`");
			$jyoukyou_list->execute();
			while(my $v = $jyoukyou_list->fetchrow_hashref){
				print "<style>.jyoukyou_type_$v->{id} { color: hsla($v->{hsl}, 1); }</style>";
				$jyoukyou_type{$v->{jyoukyou}} = $v->{id};
				$jyoukyou_class{$v->{jyoukyou}} = $v->{class};
				push @jyoukyou_name, $v->{jyoukyou};
			}
			print "<div class='koyomi'>";
				for(my $i = $koyomi_week_count; $i > 0; $i--){
					print "<div class='sihanki'>" if ($i == 53 || ($i == 52 && $koyomi_week_count == 52)) || ($i % 13 == 0 && $i < 52);
					my $week_abs = week_delta($imagenzai, ${\(week_border(${\(week($dst_musi_week_limit_lower))[0]}, $i))[0]});
					print "<div class='syuu hannyou type_${\(sub { return ${koyomi_hantyuu_winner{${\(week($dst_musi_week_limit_lower))[0]}.${\(sprintf(\"%02s\", $i))}}[1]} if defined ${koyomi_hantyuu_winner{${\(week($dst_musi_week_limit_lower))[0]}.${\(sprintf(\"%02s\", $i))}}[1]}}->())} ${\(sub { return ' highlight_syuu' if $week_abs==$week && ${\(week_border(${\(week($dst_musi_week_limit_lower))[0]}, $i))[0]} < $imagenzai }->())}'>";
						print "<span>";
						print ${\(week_border(${\(week($dst_musi_week_limit_lower))[0]}, $i))[0]} < $imagenzai && $week != $week_abs ? "<a href='${\(url_get_tuke(\%url_get, 'week', $week_abs))}'>$i</a>" : "<span>$i</span>";
						print "</span>";
					print "</div>";
					print "</div>" if ($i % 13 == 1 && $i != 53);
				}
			print "</div>";
			print "<div class='syuu_mekuri'>";
				print "<div class='tosituki'>";
					print "<div class='year'>";
					print ${\(date_split($week_limit_lower, 0))} eq ${\(date_split($week_limit_upper, 0))} ? "<span class='hito'>${\(date_split($dst_musi_week_limit_lower, 0))}</span>" : "<span class='futa'>${\(date_split($week_limit_lower, 0))}<br>${\(date_split($week_limit_upper, 0))}</span>";
					print "</div>";
					print "<div class='month'>";
					print ${\(date_split($week_limit_lower, 1))} eq ${\(date_split($week_limit_upper, 1))} ? "<span class='hito'>${\(date_split($dst_musi_week_limit_lower, 1))}</span>" : "<span class='futa'><sup>${\(date_split($week_limit_lower, 1))}</sup>⁄<sub>${\(date_split($week_limit_upper, 1))}</sub></span>";
					print "</div>";
				print "</div>";
				my $day = 0;
				my $rireki_nijiran = $dbh->prepare($meirei[1]);
				$rireki_nijiran->execute($week_limit_lower, $week_limit_upper, @sitazi_bind);
				my $rireki_nijiran_result = $rireki_nijiran->fetchall_arrayref();
				#for(my $i=0; $i<scalar(@$rireki_nijiran_result); $i++){$rireki_nijiran_result->[$i] = $rireki_nijiran_result->[$i][0]}
				for(my $i = 0; $i < 7; $i++){
					#　既に実行されていますからもう一度実行できないということです。
					#　実装する場合にはfetchallはたまたselectallで事前に使いなさい。それでforでループして。
					my $day_count = 0;
					my %mekuri_color;
					foreach my $j (@$rireki_nijiran_result){
						$day_count++ if $j->[0] > $week_limit_lower+$day && $j->[0] < $week_limit_lower+$day+86400;
						$mekuri_color{$j->[1]}++ if $j->[0] > $week_limit_lower+$day && $j->[0] < $week_limit_lower+$day+86400;
					}
					print %mekuri_color ? "<div class='youbi hannyou type_${\(hash_max_key(%mekuri_color))}'>" : "<div class='youbi'>";
						print "<div class='youbi day_${\(date_split($dst_musi_week_limit_lower+$day, 6))}'>${\(date_split($dst_musi_week_limit_lower+$day, 5))}</div>";
						print "<div class='hiduke'>${\(date_split($dst_musi_week_limit_lower+$day, 2))}</div>";
						print "<div class='kensuu'><span>${day_count}${\(Kahifu::Template::dict('JOSUU_KEN'))}</span></div>";
					print "</div>";
					$day = $day + 86400;
				}
			print "</div>";
		}
	print "</div>";
	
	print "<div class='migi'>";
		print "<div class='maegaki'>";
			print "<p>${\(Kahifu::Template::dict('HYOUKA_MAEGAKI'))}</p>";
		print "</div>";
		print "<div class='kinkyou'>";
			print "<p><span>${\(Kahifu::Template::dict('KINKYOU_HEADING'))}</span>さあ、どうでしょうね。</p>";
		print "</div>";
		print "<div class='control'>";
			print "<form method='post'>";
			print "<input type='submit' name='paginate' value='${\(Kahifu::Template::dict('PAGINATE_1'))}'";
				print " disabled=disabled" if $paginate == 1;
			print ">";
			print "<input type='submit' name='favorite' value='${\(Kahifu::Template::dict('PAGINATE_2'))}'";
				print " disabled=disabled" if $paginate == 2;
			print ">";
			print "<input type='submit' name='rireki' value='${\(Kahifu::Template::dict('PAGINATE_3'))}'";
				print " disabled=disabled" if $paginate == 3;
			print ">";
			print "</form>";
		print "</div>";
		print "<div class='narabikae'>";
			print "<form method='post'>";
			print "<div class='hidari'>";
				print "<div class='siborikomibako'>";
					print "<select name='page_siborikomi_hantyuu' class='hantyuu_all'>";
					for my $i (0 .. scalar @hantyuu_type - 1) {
						print "<option class='hantyuu_$hantyuu_class[$i]' value='$hantyuu_type[$i]' ${\( sub { return 'selected=selected' if ${siborikomi_hantyuu}==$hantyuu_type[$i] }->() )}>${\(Kahifu::Template::dict('HYOUKA_HANTYUU_' . $hantyuu_type[$i]))}</option>";
					}
					print "</select>";
					print "<select class='jyoukyou_type_1' name='page_siborikomi_jyoukyou'>";
					for my $i (0 .. scalar @jyoukyou_name - 1) {
						print "<option class='jyoukyou_type_${\($i+1)} $jyoukyou_class{$jyoukyou_name[$i]}' value='${\($i+1)}' ${\( sub { return 'selected=selected' if defined ${siborikomi_jyoukyou} && ${siborikomi_jyoukyou}==${\($i+1)} }->() )}>${\(Kahifu::Template::dict('HYOUKA_JYOUKYOU_' . ${\($i+1)}))}</option>";
					}
					print "</select>";
					print "<select name='narabi'>";
						print "<option value='1'${\( sub { return 'selected=selected' if $narabi==1 }->() )}>${\(Kahifu::Template::dict('NARABIKAE_1'))}</option>";
						print "<option value='2'${\( sub { return 'selected=selected' if $narabi==2 }->() )}>${\(Kahifu::Template::dict('NARABIKAE_2'))}</option>";
						print "<option value='3'${\( sub { return 'selected=selected' if $narabi==3 }->() )}>${\(Kahifu::Template::dict('NARABIKAE_3'))}</option>";
						print "<option value='4'${\( sub { return 'selected=selected' if $narabi==4 }->() )}>${\(Kahifu::Template::dict('NARABIKAE_4'))}</option>";
					print "</select>";
					print "<select name='jun'>";
						print "<option value='0'${\( sub { return 'selected=selected' if $jun==0 }->() )}>↓</option>"; #降順
						print "<option value='1'${\( sub { return 'selected=selected' if $jun==1 }->() )}>↑</option>"; #昇順				
					print "</select>";
				print "</div>";
				print "<div class='kensakubako'>";
					print "<input type='text' name='kensaku' placeholder='${\(Kahifu::Template::dict('KENSAKU_PLACEHOLDER'))}' value='${\( sub { return $kensaku if defined ${kensaku} }->() )}'>";
				print "</div>";
			print "</div>";
			print "<div class='botanbako'>";
				print "<input type='submit' value='${\(Kahifu::Template::dict('KETTEI'))}' name='narabikae_kettei'>";
				print "<input type='submit' value='${\(Kahifu::Template::dict('KAIJYO'))}' name='kaijyo'>" if (param('kensaku'));
			print "</div>";
			print "</form>";
		print "</div>";
	print "</div>";
print "</div>";

#　初期レイアウト（頁化欄）
#　PAGINATE=1
#
if($paginate == 1){
	# 管理人　→記録ツール
	if(Kahifu::Template::tenmei()){
		print "<div data-kakejiku='kiroku' class='kakejiku kiroku'>";
			print "<span>${\(Kahifu::Template::dict('KIROKU_SINSYUKU'))}<span class='sinsyuku'>${\(Kahifu::Template::dict('SINSYUKU_PLUS'))}</span></span>";
		print "</div>";
		print "<div data-kakejiku='kiroku' class='form kiroku'>";
			print "<form method='post' action='kiroku.pl'>";
			print "<div class='cream'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_TITLE'))}</span><input type='text' name='midasi' placeholder='${\(Kahifu::Template::dict('KIROKU_TITLE_PLACEHOLDER'))}'></div>";
			print "<div class='cream'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_SUBTITLE'))}</span><input type='text' name='fukumidasi' placeholder='${\(Kahifu::Template::dict('KIROKU_SUBTITLE_PLACEHOLDER'))}'></div>";
			print "<div class='sky'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_SAKKA'))}</span><input type='text' name='sakka' placeholder='${\(Kahifu::Template::dict('KIROKU_SAKKA_PLACEHOLDER'))}'></div>";
			print "<div class='mint'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_HANTYUU'))}</span><input type='text' name='hantyuu' placeholder='${\(Kahifu::Template::dict('KIROKU_HANTYUU_PLACEHOLDER'))}'></div>";
			print "<div class='strawberry'><span class='block'>${\(Kahifu::Template::dict('KIROKU_COLLECTION'))}</span><input type='text' name='colle' placeholder='${\(Kahifu::Template::dict('KIROKU_COLLECTION_PLACEHOLDER'))}'></div>";
			print "<div class='ajisai'><span class='block'>${\(Kahifu::Template::dict('KIROKU_BIKOU'))}</span><input type='text' name='bikou' placeholder='${\(Kahifu::Template::dict('KIROKU_BIKOU_PLACEHOLDER'))}'></div>";
			print "<div class='ajisai'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_WHOLE'))}</span><input type='text' name='whole' placeholder='${\(Kahifu::Template::dict('KIROKU_WHOLE_PLACEHOLDER'))}'></div>";
			print "<div class='meadow'><span>${\(Kahifu::Template::dict('KIROKU_JOSUU'))}</span>";
				print "<select placeholder='${\(Kahifu::Template::dict('KIROKU_JOSUU_PLACEHOLDER'))}' name='josuu'>";
				print "<option value='無'>${\(Kahifu::Template::dict('NONE'))}</option>";
				for my $j (@josuu_tati){ print "<option value='$j->[0]'>$j->[0]</option>"; }
				print "</select>&nbsp;";
			print "</div>";
			print "<div class='cream'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_MIKAKUTEI'))}</span>";
				print "<div class='radio_box'><input type='radio' id='mikakutei0' name='hide' value='0'><label for='mikakutei0'>${\(Kahifu::Template::dict('KIROKU_MIKAKUTEI_OPTION_1'))}<span></span></label><input type='radio' id='mikakutei1' name='hide' value='1' checked><label for='mikakutei1'>${\(Kahifu::Template::dict('KIROKU_MIKAKUTEI_OPTION_2'))}<span></span></label></div>";
			print "</div>";
			print "<div class='cream'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_KANSYOUZUMI'))}</span>";
				print "<div class='radio_box'><input type='radio' id='kansyouzumi1' name='kansyouzumi' value='1'><label for='kansyouzumi1'>${\(Kahifu::Template::dict('KIROKU_KANSYOUZUMI_OPTION_1'))}<span></span></label><input type='radio' id='kansyouzumi0' name='kansyouzumi' value='0' checked><label for='kansyouzumi0'>${\(Kahifu::Template::dict('KIROKU_KANSYOUZUMI_OPTION_2'))}<span></span></label></div>";
			print "</div>";
			print "<div class='cream'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_YOTEI'))}</span>";
				print "<div class='radio_box'><input type='radio' id='yotei0' name='yotei' value='0' checked><label for='yotei0'>${\(Kahifu::Template::dict('KIROKU_YOTEI_OPTION_1'))}<span></span></label><input type='radio' id='yotei1' name='yotei' value='1'><label for='yotei1'>${\(Kahifu::Template::dict('KIROKU_YOTEI_OPTION_2'))}<span></span></label></div>";
			print "</div>";
			print "<div class='meadow'><span class='block'>${\(Kahifu::Template::dict('KIROKU_HAJIMARI'))}</span>";
				print "<div class='time_box'>";
				print "<input type='text' name='tosi_hajimari' placeholder='${\(date_split($imagenzai, 0))}'>${\(Kahifu::Template::dict('TOSI'))}";
				print "<input type='text' name='tuki_hajimari' placeholder='${\(date_split($imagenzai, 1))}'>${\(Kahifu::Template::dict('TUKI'))}";
				print "<input type='text' name='hi_hajimari' placeholder='${\(date_split($imagenzai, 2))}'>${\(Kahifu::Template::dict('HI'))}";
				print "<input type='text' name='ji_hajimari' placeholder='${\(date_split($imagenzai, 3))}'>${\(Kahifu::Template::dict('JI'))}";
				print "<input type='text' name='fun_hajimari' placeholder='${\(sprintf(\"%02s\", date_split($imagenzai, 4)))}'>${\(Kahifu::Template::dict('FUN'))}";
				print "<input type='text' name='unix_hajimari' placeholder='${imagenzai}'>";
				print "</div>";
			print "</div>";
			print "<div class='ajisai hazusi'><input type='submit' value='${\(Kahifu::Template::dict('KIROKU_SUBMIT'))}'></div>";
			print "</form>";
		print "</div>";
	}
	my $loop_hajime = 0;
	$loop_hajime = 1 if $page != 1;
	for(my $loop = $loop_hajime; ($loop < 2 && $ninsyou) || $loop < 1; $loop++){
		print "<div class='info'>";
		print "<div class='sakuhin'>$daimei[$loop]";
		# page in here
		print "</div>";
		print "<div class='jyou'>${\(Kahifu::Template::dict('HEADING_JYOUKYOU'))}</div>";
		print "<div class='hantyuu'>${\(Kahifu::Template::dict('HEADING_HANTYUU'))}</div>";
		print "<div class='ten'>${\(Kahifu::Template::dict('HEADING_POINT'))}</div>" if $narabi == 4;
		print "</div>";
		#print decode_utf8(param('kensaku')) if param('kensaku');
		#$dbh->trace(2); #debug sql
		push @sitazi_bind, ($page_offset) if $loop == 1;
		my $sakuhin = $dbh->prepare($meirei[$loop]);
		$sakuhin->execute(@sitazi_bind);
		while(my $v = $sakuhin->fetchrow_hashref){
		if(((not defined $v->{kakusu}) || $v->{kakusu}!=1) || Kahifu::Template::tenmei()){
			print "<div class='koumoku type_$v->{hantyuu}${\( sub { return ' hankakusi' if defined $v->{kakusu} && $v->{kakusu}==1 }->() )}'>";
				print "<div class='sakuhinmei'>";
					print "<p id='$v->{id}' class='midasi $v->{id}' data-kansou='$v->{id}'>";
					print midasi_settei($v->{midasi}, $v->{mikakutei}, $v->{current}, $kensaku);
					print "</p>";
					print "<p class='fuku_midasi $v->{id}'>$v->{fukumidasi}</p>" if $v->{fukumidasi} ne '';
					print "<span class='sakka'>" . sakka_settei($v->{sakka}, $kensaku) . "</span>" if defined $v->{sakka};				
				print "</div>";
				print "<div class='jyou'>";
					print "<div class='jyoukyou' data-jyoutype='$v->{jyoukyou}' data-jyoukyou='$v->{id}'>";
						my $jyoukyou_syori = jyoukyou_settei($v->{jyoukyou}, $v->{hajimari}, $v->{owari}, $v->{current}, $v->{eternal});
						print "<span class='jyoukyou_type_$jyoukyou_type{$jyoukyou_syori} $jyoukyou_class{$jyoukyou_syori}'>";
						print $jyoukyou_syori;
						print "</span>";
					print "</div>";
					print "<span class='jyouhou' data-jyouhou='$v->{id}'>";
					print $v->{part};
					print defined $v->{eternal} && $v->{eternal} == 1 ? "" : "／$v->{whole}";
					print $v->{josuu};
					print "</span>";
				print "</div>";
				print "<div class='hantyuu'>";
					print "<a href='${\(url_get_tuke(\%url_get, 'id', $v->{id}))}'>";
					print "${\(Kahifu::Template::dict('HYOUKA_HANTYUU_' . $v->{hantyuu}))}";
					print "</a>";
				print "</div>";
				print "<div class='ten'>", $v->{point}, "</div>" if $narabi == 4;
				# 更新するために Initialize "activity_kousin"
				print "<div id='ak_$v->{id}' class='activity_kousin'>";
				print "<form method='post' action='kousin.pl'>";
					print "<input type='hidden' name='reference' value='$v->{id}'>";
					print "<input type='number' size='5' placeholder='${\(Kahifu::Template::dict('KOUSIN_PART_PLACEHOLDER'))}' name='part' value='$v->{part}'>";
					print "／<input type='number' size='5' placeholder='${\(Kahifu::Template::dict('KOUSIN_WHOLE_PLACEHOLDER'))}' name='whole' value='$v->{whole}'>";
					print "<select placeholder='${\(Kahifu::Template::dict('KIROKU_JOSUU_PLACEHOLDER'))}' name='josuu'>";
					for my $j (@josuu_tati){ print "<option value='$j->[0]'>$j->[0]</option>"; }
					print "</select>&nbsp;";
					print "<select placeholder='${\(Kahifu::Template::dict('HEADING_JYOUKYOU'))}' name='mode'>";
						print "<option value='0'>${\(Kahifu::Template::dict('KOUSIN_MAKASE'))}</option>";
						print "<option value='1'>${\(Kahifu::Template::dict('KOUSIN_TUMU'))}</option>";
						print "<option value='2'>${\(Kahifu::Template::dict('KOUSIN_OTOSU'))}</option>";
						print "<option value='3'>${\(Kahifu::Template::dict('KOUSIN_SAI'))}</option>";
						print "<option value='7' disabled>${\(Kahifu::Template::dict('KOUSIN_MOTO'))}</option>";
						print "<option value='4'>${\(Kahifu::Template::dict('KOUSIN_TOBU'))}</option>";
						print "<option value='5'>${\(Kahifu::Template::dict('KOUSIN_HAPPA'))}</option>";
					print "</select>　";
					print "<input type='submit' name='kiroku' value='${\(Kahifu::Template::dict('KIROKU_SUBMIT'))}'>";
					print "<div><input type='text' size='30' placeholder='${\(Kahifu::Template::dict('KOUSIN_TITLE_PLACEHOLDER'))}' name='title' value=''></div>";
					print "<div class='hiduke_collection'>";
						print "<div class='kousin_hiduke'>";
							print "<span>${\(Kahifu::Template::dict('KOUSIN_MIKAKUTEI_1'))}</span>";
							print "<input id='jikoku_mikakutei1' type='radio' name='jikoku_mikakutei' value='1'>";
							print "<label for='jikoku_mikakutei1'><span>${\(Kahifu::Template::dict('FORM_YES'))}</span></label>";
							print "<input id='jikoku_mikakutei2' type='radio' name='jikoku_mikakutei' value='0' checked='checked'>";
							print "<label for='jikoku_mikakutei2'><span>${\(Kahifu::Template::dict('FORM_NO'))}</span></label>";
							print "<span>${\(Kahifu::Template::dict('KOUSIN_MIKAKUTEI_2'))}</span>";
							print "<br>";
							print "<input type='text' size='6' placeholder='${\(date_split($imagenzai, 0))}' name='tosi_owari'>";
							print "<input type='text' size='3' placeholder='${\(date_split($imagenzai, 1))}' name='tuki_owari'>";
							print "<input type='text' size='3' placeholder='${\(date_split($imagenzai, 2))}' name='hi_owari'>";
							print "<input type='text' size='3' placeholder='${\(date_split($imagenzai, 3))}' name='ji_owari'>";
							print "<input type='text' size='3' placeholder='${\(sprintf(\"%02s\", date_split($imagenzai, 4)))}' name='fun_owari'>";
							print "<br>";
							print "<input type='text' size='29' placeholder='$imagenzai' name='unix_owari' value=''>";
						print "</div>";
						print "<div class='hajimari_hiduke'>";
							print "<span>${\(Kahifu::Template::dict('KOUSIN_HAJIMARI'))}</span>";
							print "<br>";
							print "<input type='text' size='6' placeholder='${\(date_split($v->{hajimari}, 0))}' name='tosi_hajimari'>";
							print "<input type='text' size='3' placeholder='${\(date_split($v->{hajimari}, 1))}' name='tuki_hajimari'>";
							print "<input type='text' size='3' placeholder='${\(date_split($v->{hajimari}, 2))}' name='hi_hajimari'>";
							print "<input type='text' size='3' placeholder='${\(date_split($v->{hajimari}, 3))}' name='ji_hajimari'>";
							print "<input type='text' size='3' placeholder='${\(sprintf(\"%02s\", date_split($v->{hajimari}, 4)))}' name='fun_hajimari'>";
							print "　";
							print "<input type='text' size='3' placeholder='${\(Kahifu::Template::dict('KOUSIN_JUNNI'))}' name='junni'>";
							print "<br>";
							print "<input type='text' size='29' placeholder='$v->{hajimari}' name='unix_hajimari' value=''>";
						print "</div>";
						print "<div class='sakujyo'>";
							print "<span>${\(Kahifu::Template::dict('SAKUJYO'))}</span>";
							print "<br>";
							print "<input type='submit' name='sakujyo' value='${\(Kahifu::Template::dict('SAKUJYO'))}'>&nbsp;";
							print "<input type='submit' name='touroku_sakujyo' value='${\(Kahifu::Template::dict('TOUROKU_SAKUJYO'))}'>";
						print "</div>";
					print "</div>";
				print "</form>";
				print "</div>";
				# 履歴を初期化する Initialize "rireki"
				print "<div id='a_$v->{id}' class='activity'>";
				print "<div class='rireki_kakera'><div class='rirekinai_jyoukyou'><div class='jyoukyou'><span class='jyoukyou_type_1'>始</span></div></div><div class='rirekinai_hiduke'>", date($v->{hajimari}, $v->{mikakutei}),"</div></div>";
				my $kansyou_kaisuu = 0;
				foreach(@r){
					if ($_->[1] == $v->{id}){
						print "<div class='rireki_kakera'>";
							print "<div class='rirekinai_jyoukyou'>";
								print "<div class='jyoukyou'>";
								my $jyoukyou_syori = jyoukyou_settei($_->[5], $_->[2], $_->[2], 609, 609);
								print "<span class='jyoukyou_type_$jyoukyou_type{$jyoukyou_syori} $jyoukyou_class{$jyoukyou_syori}'>";
								print $jyoukyou_syori;
								print "</div>";
								$kansyou_kaisuu++ if $_->[5] eq '終';
								print "<span class='kaisuu'>${\(Kahifu::Infra::nihon_suuji($kansyou_kaisuu))}</span>" if defined $kansyou_kaisuu && $kansyou_kaisuu > 1 && $_->[5] eq '終';
							print "</div>";
							print "<div title='", date_split($_->[2], 8),"' class='rirekinai_hiduke'>";
							print date($_->[2], $_->[7]);
							print "</div>";
							print "<div class='rirekinai_sinkou'>";
							print $_->[3];
							print defined $v->{eternal} && $v->{eternal} == 1 ? "" : "／$_->[4]";
							print $_->[6];
							print "</div>";
							print "<div class='rireki_title'>";
							print $_->[8];
							print "</div>";
						print "</div>";
					}
				}
				print "</div>";
				# 感想箱（kansou）を初期化
				print "<div class='kansou' data-kansou='$v->{id}'>";
					#print "<p>";
					print Kahifu::Infra::bunsyou($v->{kansou}) if defined $v->{kansou};
					print "<a class='tuduki' href='${\(url_get_tuke(\%url_get, 'id', $v->{id}))}'>${\(Kahifu::Template::dict('KANSOU_TUDUKI'))}</a>" if defined $v->{extend} && $v->{extend} == 1;
					#print "</p>";
				print "</div>";
				# 作品編集箱（kansou_kousin）を初期化
				print "<div id='kk_$v->{id}' class='kansou_kousin'>";
					print "<form id='kansou_$v->{id}' method='post' action='kansou.pl' >";
					print "<input type='hidden' name='reference' value='$v->{id}'>";
					print "<div class='midasi_kousin'>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_TITLE'))}</div><div><input type='text' size='30' placeholder='$v->{midasi}' name='midasi' value='$v->{midasi}'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_HANTYUU'))}</div><div><input type='text' size='15' placeholder='$v->{hantyuu}' name='hantyuu' value='", ${\(Kahifu::Template::dict('HYOUKA_HANTYUU_' . $v->{hantyuu}))}//'', "'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_SUBTITLE'))}</div><div><input type='text' size='30' placeholder='", $v->{fukumidasi}//'', "' name='fukumidasi' value='", $v->{fukumidasi}//'', "'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_SAKKA'))}</div><div><input type='text' size='20' placeholder='", $v->{sakka}//'', "' name='sakka' value='", $v->{sakka}//'', "'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_BETUMEI'))}</div><div><input type='text' size='20' placeholder='", $v->{betumei}//'', "' name='betumei' value='", $v->{betumei}//'', "'></div></div>";
					print "</div>";
					print "<div class='extra'>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_THEME'))}</div><div><input type='text' size='20' placeholder='", $v->{theme}//'', "' name='theme' value='", $v->{theme}//'', "'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_GYOUSUU'))}</div><div><input type='text' size='20' placeholder='", $v->{gyousuu}//'', "' name='gyousuu' value='${\(sub { return $v->{gyousuu} if defined $v->{gyousuu} }->())}'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_BG_IMG'))}</div><div><input type='text' size='40' placeholder='", $v->{bg_img}//'', "' name='bg_img' value='", $v->{bg_img}//'', "'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_ETERNAL'))}</div><div><input id='mugen$v->{id}1' type='radio' name='eternal' value='1'${\( sub { return 'checked=checked' if defined $v->{eternal} && $v->{eternal}==1 }->() )}><label for='mugen$v->{id}1'>${\(Kahifu::Template::dict('IRI'))}</label><input id='mugen$v->{id}2' type='radio' name='eternal' value='0'${\( sub { return 'checked=checked' if defined $v->{eternal} && $v->{eternal}==0 || not defined $v->{eternal} }->() )}><label for='mugen$v->{id}2'>${\(Kahifu::Template::dict('KIRI'))}</label></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_CURRENT'))}</div><div><input id='current$v->{id}1' type='radio' name='current' value='1'${\( sub { return 'checked=checked' if defined $v->{current} && $v->{current}==1 }->() )}><label for='current$v->{id}1'>${\(Kahifu::Template::dict('AGE'))}</label><input id='current$v->{id}2' type='radio' name='current' value='0'${\( sub { return 'checked=checked' if defined $v->{current} && $v->{current}==0 || not defined $v->{current} }->() )}><label for='current$v->{id}2'>${\(Kahifu::Template::dict('KIRI'))}</label><input id='current$v->{id}3' type='radio' name='current' value='2'${\( sub { return 'checked=checked' if defined $v->{current} && $v->{current}==2 }->() )}><label for='current$v->{id}3'>${\(Kahifu::Template::dict('SAGE'))}</label><input id='current$v->{id}4' type='radio' name='current' value='3'${\( sub { return 'checked=checked' if defined $v->{current} && $v->{current}==3 }->() )}><label for='current$v->{id}4'>${\(Kahifu::Template::dict('DARAKU'))}</label></div></div>";
					print "</div>";
					print "<div class='super_extra'>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_MIKAKUTEI_ALT'))}</div><div><input id='mikakutei$v->{id}1' type='radio' name='mikakutei' value='1'${\( sub { return 'checked=checked' if defined $v->{mikakutei} && $v->{mikakutei}==1 }->() )}><label for='mikakutei$v->{id}1'>${\(Kahifu::Template::dict('IRI'))}</label><input id='mikakutei$v->{id}0' type='radio' name='mikakutei' value='0'${\( sub { return 'checked=checked' if defined $v->{mikakutei} && $v->{mikakutei}==0 || not defined $v->{mikakutei} }->() )}><label for='mikakutei$v->{id}0'>${\(Kahifu::Template::dict('KIRI'))}</label></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_YOTEI_ALT'))}</div><div><input id='yotei$v->{id}1' type='radio' name='yotei' value='1'${\( sub { return 'checked=checked' if defined $v->{yotei} && $v->{yotei}==1 }->() )}><label for='yotei$v->{id}1'>${\(Kahifu::Template::dict('IRI'))}</label><input id='yotei$v->{id}0' type='radio' name='yotei' value='0'${\( sub { return 'checked=checked' if defined $v->{yotei} && $v->{yotei}==0 || not defined $v->{yotei} }->() )}><label for='yotei$v->{id}0'>${\(Kahifu::Template::dict('KIRI'))}</label></div></div>" if $v->{part} == 0;
					print "</div>";
					print "<div class='colle'><div><div>${\(Kahifu::Template::dict('KIROKU_COLLECTION_ALT'))}</div><div><input type='text' size='30' name='collection' placeholder='' value='", $v->{colle}//'', "'></div></div></div>";
					print "<div class='bunsyou'><textarea name='kansou' form='kansou_$v->{id}'>", $v->{kansou}//'', "</textarea></div>";
					print "<div class='meirei'><input type='submit' name='kousin' value='${\(Kahifu::Template::dict('KIROKU_KOUSIN'))}'></div>";
					print "</form>";
				print "</div>";
			print "</div>";
		} # if kakusu etc.
		}	# while sakuhin…
	}
	print "<script>
	\$(function()
			{
			\$('div.navi > span').click(function()
			  {
				var span = \$(this);
				var text = ${page};
				var new_text = prompt(\"${\(Kahifu::Template::dict('WEEK_NUMBER'))}\", text);
				const params = new URLSearchParams(window.location.search);
				if (new_text != null && Number.isInteger(parseInt(text)) && new_text != text){
					params.set('page', new_text);
					window.location.search = params;
				}
			  });
			});	
		</script>";
} elsif($paginate == 2){
	#　コレクション（蒐集・殿堂欄）
	#　PAGINATE=2
	#
	my ($midasi_recall, $meisyou_recall, $hyouji_ja, $hyouji_en, $turu_recall, $tag_recall, $gaiyouran_recall, $bikou_recall, $hide_recall, $bikouiti_recall, $kansou_hyouji_recall);
	if(Kahifu::Template::tenmei()){
		if(defined param('collection')){
			my $meirei = ("select * from collection where `id` = ?");
			my $collection_sitami = $dbh->prepare($meirei);
			my $collection_id = (defined param('collection')) ? param('collection') : '1';
			$collection_sitami->execute($collection_id);
			my $v = $collection_sitami->fetchrow_hashref;
			$midasi_recall = $v->{midasi};
			$meisyou_recall = $v->{midasi_seisiki};
			my $hyouji_recall = $v->{hyouji};
			my $unserialize_hyouji = from_json($hyouji_recall);
			$hyouji_ja = $unserialize_hyouji->{ja};
			$hyouji_en = $unserialize_hyouji->{en};
			$turu_recall = $v->{turu};
			$tag_recall = $v->{tag};
			$gaiyouran_recall = $v->{gaiyouran};
			my $bikou_get = $v->{bikou};
			my $bikou_unserialized = from_json($bikou_get);
			if(ref($bikou_unserialized) ne "ARRAY"){
				foreach my $key ( keys %$bikou_unserialized ) { 
			   	$bikou_recall .= $key . "::" . $bikou_unserialized->{$key} . "++\n";
				}
			} else { $bikou_recall = ""; }
			$bikouiti_recall = $v->{bikouiti};
			$hide_recall = $v->{hide};
			$kansou_hyouji_recall = $v->{kansou_hyouji};
		}
		print "<div data-kakejiku='colle_info' class='kakejiku colle_info'>";
			print "<span>${\(Kahifu::Template::dict('COLLE_SINSYUKU'))}<span class='sinsyuku'>${\(Kahifu::Template::dict('SINSYUKU_PLUS'))}</span></span>";
		print "</div>";
		print "<div data-kakejiku='colle_info' class='form colle_info'>";
			print "<form id='collection_form' method='post' action='collection.pl'>";
			print "<div class='cream'><span class='block'>${\(Kahifu::Template::dict('COLLE_MIDASI'))}</span><input type='text' name='midasi' placeholder='見出し' value='${\(sub { return $midasi_recall if defined $midasi_recall }->())}'></div>";
			print "<div class='cream'><span class='block'>${\(Kahifu::Template::dict('COLLE_MIDASI_SEISIKI'))}</span><input type='text' name='midasi_seisiki' placeholder='正式名称' value='${\(sub { return $meisyou_recall if defined $midasi_recall }->())}'></div>";
			print "<div class='ajisai'><span class='block'>${\(Kahifu::Template::dict('COLLE_HYOUJI_JA'))}</span><input type='text' name='hyouji/ja' placeholder='日本語の何か' value='${\(sub { return $hyouji_ja if defined $hyouji_ja }->())}'></div>";
			print "<div class='ajisai'><span class='block'>${\(Kahifu::Template::dict('COLLE_HYOUJI_EN'))}</span><input type='text' name='hyouji/en' placeholder='英語の何か' value='${\(sub { return $hyouji_en if defined $hyouji_en }->())}'></div>";
			print "<div class='strawberry'><span class='block'>${\(Kahifu::Template::dict('COLLE_TURU'))}</span><input type='text' name='turu' placeholder='1,2,4,7' value='${\(sub { return $turu_recall if defined $turu_recall }->())}'></div>";
			print "<div class='mint'><span class='block'>${\(Kahifu::Template::dict('COLLE_TAG'))}</span><input type='text' name='tag' placeholder='award' value='${\(sub { return $tag_recall if defined $tag_recall }->())}'></div>";
			print "<div class='ajisai'><span class='fixed'>${\(Kahifu::Template::dict('COLLE_DESCRIPTION'))}</span><textarea form='collection_form' name='gaiyouran'>${\(sub { return $gaiyouran_recall if defined $gaiyouran_recall }->())}</textarea></div>";
			print "<div class='mint'><span class='block'>${\(Kahifu::Template::dict('COLLE_BIKOU'))}</span><textarea form='collection_form' name='bikou'>${\(sub { return $bikou_recall if defined $bikou_recall }->())}</textarea></div>";
			print "<div class='cream'><span>${\(Kahifu::Template::dict('COLLE_KAKUSU'))}</span>";
				print "<div class='radio_box'><input type='radio' id='collekakusu0' name='hide' value='0'${\( sub { return ' checked=checked' if defined $hide_recall && $hide_recall == 0 || not defined $hide_recall }->() )}><label for='collekakusu0'>${\(Kahifu::Template::dict('COLLE_KAKUSU_OPTION_1'))}<span></span></label><input type='radio' id='collekakusu1' name='hide' value='1' ${\( sub { return ' checked=checked' if defined $hide_recall && $hide_recall == 1 }->() )}><label for='collekakusu1'>${\(Kahifu::Template::dict('COLLE_KAKUSU_OPTION_2'))}<span></span></label></div>";
			print "</div>";
			print "<div class='cream'><span>${\(Kahifu::Template::dict('COLLE_BIKOUITI'))}</span>";
				print "<div class='radio_box'><input type='radio' id='bikoustyle1' name='bikouiti' value='1'${\( sub { return ' checked=checked' if defined $bikouiti_recall && $bikouiti_recall==1 }->() )}><label for='bikoustyle1'><span>${\(Kahifu::Template::dict('HIDARI'))}</span></label><input type='radio' id='bikoustyle0' name='bikouiti' value='0'${\( sub { return ' checked=checked' if defined $bikouiti_recall && $bikouiti_recall==0 || not defined $bikouiti_recall }->() )}><label for='bikoustyle0'>${\(Kahifu::Template::dict('MIGI'))}<span></span></label><input type='radio' id='bikoustyle2' name='bikouiti' value='2'${\( sub { return ' checked=checked' if defined $bikouiti_recall && $bikouiti_recall==2 }->() )}><label for='bikoustyle2'><span>${\(Kahifu::Template::dict('UE'))}</span></label><input type='radio' id='bikoustyle3' name='bikouiti' value='3'${\( sub { return ' checked=checked' if defined $bikouiti_recall && $bikouiti_recall==3 }->() )}><label for='bikoustyle3'>${\(Kahifu::Template::dict('SITA'))}<span></span></label></div>";
			print "</div>";
			print "<div class='cream'><span>${\(Kahifu::Template::dict('COLLE_KANSOU_HYOUJI'))}</span>";
				print "<div class='radio_box'><input type='radio' id='kansouhyouji0' name='kansou_hyouji' value='0'${\( sub { return ' checked=checked' if defined $kansou_hyouji_recall && $kansou_hyouji_recall==0 || not defined $kansou_hyouji_recall }->() )}><label for='kansouhyouji0'><span>${\(Kahifu::Template::dict('HIHYOUJI'))}</span></label><input type='radio' id='kansouhyouji1' name='kansou_hyouji' value='1'${\( sub { return ' checked=checked' if defined $kansou_hyouji_recall && $kansou_hyouji_recall==1 }->() )}><label for='kansouhyouji1'>${\(Kahifu::Template::dict('HYOUJI'))}<span></span></label></div>";
			print "</div>";
			print "<div class='ajisai hazusi'><input type='submit' name='${\( sub { return defined param('collection') ? 'colle_hensyuu' : 'colle_sinkiroku' }->() )}' value='${\(Kahifu::Template::dict('COLLE_SUBMIT'))}'></div>";
			print "</form>";
		print "</div>";
	}
	if(defined param('collection')){
		#　コレクション内 （Inside the collection）
		my $meirei = ("select * from collection where `id` = ?");
		my $collection = $dbh->prepare($meirei);
		my $collection_id = (defined param('collection')) ? param('collection') : '1';
		$collection->execute($collection_id);
		my $v = $collection->fetchrow_hashref;
		# 蔓の内容を決まる、特にspecial scenario colle=1
		my (@turu, $turu_sitazi);
		my %jyoukyou_colle;
		if($v->{id} == 1){
			# 予定欄の蔓を設定
			my $turu_meirei = "select saku.`id` from sakuhin saku left join rireki reki on reki.sid = saku.id where reki.sid is null order by saku.`time` desc";
			@turu = $dbh->selectall_array($turu_meirei);
			for(my $i=0; $i<scalar(@turu); $i++){$turu[$i] = $turu[$i][0]}
		} elsif($v->{midasi_seisiki} eq 'watchlist') {
			my $turu_meirei = "select saku.`id` from sakuhin saku left join rireki reki on reki.sid = saku.id where reki.sid is null and saku.`yotei` = 1 order by saku.`time` desc";
			@turu = $dbh->selectall_array($turu_meirei);
			for(my $i=0; $i<scalar(@turu); $i++){$turu[$i] = $turu[$i][0]}
		} else {
			@turu = split /,/,$v->{turu};
		}
		for(my $i=0; $i<scalar(@turu); $i++){$turu_sitazi .= '?,'}
		$turu_sitazi =~ s/,\s*$//; #　後端のコンマを削除す
		$turu_sitazi = '0' if not defined $turu_sitazi;
		#　備考を決まる
		my $bikou = from_json($v->{bikou});
		#　第二次命令　→作品欄から抽出す
		my $dainiji_meirei = ("select * from sakuhin where `id` in (${turu_sitazi}) order by field (id, ${turu_sitazi})");
		my $sakuhinran = $dbh->prepare($dainiji_meirei);
		$sakuhinran->execute(@turu, @turu);
		print "<div class='colle navi'>";
		print "</div>";
		print "<div class='colle heading'>";
			print "<span>";
			print midasi_settei($v->{midasi});
			print defined $v->{hyouji} && $v->{hyouji} && (defined from_json($v->{hyouji})->{$Kahifu::Junbi::lang}) && (from_json($v->{hyouji})->{$Kahifu::Junbi::lang}) && (from_json($v->{hyouji})->{$Kahifu::Junbi::lang} ne $v->{midasi}) ? "<span class='honnyaku'>${\(from_json($v->{hyouji})->{$Kahifu::Junbi::lang})}</span>" : "";
			print "</span>";
		print "</div>";
		print "<div class='colle gaiyouran'>";
			print Kahifu::Infra::bunsyou($v->{gaiyouran}) if defined $v->{gaiyouran};
		print "</div>";
		print "<form id='colle_box' method='post' action='narabikae.pl'>" if defined param('hensyuu');
		print "<div class='control'><input type='submit' name='saisettei' value='${\(Kahifu::Template::dict('COLLE_SAISETTEI'))}'></div>" if defined param('hensyuu');
		print "<input type='hidden' name='collection' value='$v->{id}'>";
		while(my $w = $sakuhinran->fetchrow_hashref){
			print "<div class='colle koumoku bikou_$v->{bikouiti} type_$w->{hantyuu}'>";
				print "<input type='hidden' name='junban' value='$w->{id}'>";
				print "<div class='sakuhinmei bikou_$v->{bikouiti}'>";
					print "<div class='omake id'><span>$w->{id}</span></div>" if defined param('hensyuu');
					print "<div class='bikou ue'><span>$bikou->{$w->{id}}</span></div>" if $v->{bikouiti} == 3;
					print "<div class='bikou hidari'><span>$bikou->{$w->{id}}</span></div>" if $v->{bikouiti} == 1;
					print "<div>";
						print "<p id='$w->{id}' class='midasi $w->{id}' data-kansou='$w->{id}'>";
						print "<a href='${\(url_get_tuke(\%url_get, 'id', $w->{id}))}'>";
						print midasi_settei($w->{midasi}, $w->{mikakutei}, $w->{current}, $kensaku);
						print "</a>";
						print "</p>";
						print "<p class='fuku_midasi $w->{id}'>$w->{fukumidasi}</p>" if $w->{fukumidasi} ne '';
						my $sakka_hyouji = Kahifu::Infra::mobile() ? 0 : 1;
						print "<p class='sakka'>" . sakka_settei($w->{sakka}, $kensaku, $sakka_hyouji) . "</p>" if defined $w->{sakka};	
					print "</div>";			
				print "</div>";
				print "<div class='jyou'>";
					print "<div class='jyoukyou' data-jyoutype='$w->{jyoukyou}' data-jyoukyou='$w->{id}'>";
						my $jyoukyou_syori = jyoukyou_settei($w->{jyoukyou}, $w->{hajimari}, $w->{owari}, 90, $w->{eternal});
						print "<span class='jyoukyou_type_$jyoukyou_type{$jyoukyou_syori} $jyoukyou_class{$jyoukyou_syori}'>";
						print $jyoukyou_syori;
						$jyoukyou_colle{$jyoukyou_syori}++;
						print "</span>";
					print "</div>";
					print "<span class='jyouhou' data-jyouhou='$w->{id}'>";
					print $w->{part};
					print defined $w->{eternal} && $w->{eternal} == 1 ? "" : "／$w->{whole}";
					print $w->{josuu};
					print "</span>";
				print "</div>";
				print "<div class='hantyuu'>";
					print "${\(Kahifu::Template::dict('HYOUKA_HANTYUU_' . $w->{hantyuu}))}";
				print "</div>";
				print "<div class='bikou migi'><span>${\( sub { return $bikou->{$w->{id}} if ref($bikou) ne 'ARRAY' }->() )}</span></div>" if (! defined $v->{bikouiti} || defined $v->{bikouiti} && $v->{bikouiti} eq 0) && ref($bikou) ne 'ARRAY' && defined $bikou->{$w->{id}};
				print "<div class='kansou' data-kansou='$v->{id}'>";
					print Kahifu::Infra::bunsyou($w->{kansou}) if defined $v->{kansou_hyouji} && $v->{kansou_hyouji} == 1;
				print "</div>";
			print "</div>";
		}
		print "</form>" if defined param('hensyuu'); #form id=colle_box
		print "<div class='colle youyaku'>";
			while(my($k, $v) = each %jyoukyou_colle) {
				print "<div class='jyoukyou'><span class='jyoukyou_type_$jyoukyou_type{$k} $jyoukyou_class{$k}'>${k}&nbsp;${v}</span></div>";
			}
		print "</div>";
		print "<script>
			Sortable.create(colle_box, {
				filter: '.control',
				animation: 100,
				delay: 250,
				delayOnTouchOnly: true
			});
		</script>";
	} else {
		#　一覧コレクション外 （Collection listing）	
		#my $meirei = "select id, midasi, hyouji, turu, color from collection";
		my $meirei = ("select id, midasi, tag, hyouji, turu, color from collection order by field(`tag`, 'yotei', 'award', 'waku', 'misc', 'period', 'tag'), `sort1` asc, `sort2` asc");
		my $colleran = $dbh->prepare($meirei);
		print "<div>";
		print "</div>";
		$colleran->execute();
		print "<div class='collection_box'>";
		while(my $v = $colleran->fetchrow_hashref){
			print "<div class='koumoku type_$v->{color}'>";
				print "<div class='midasi'>";
					print "<span>";
					print "<a href='${\(url_get_tuke(\%url_get, 'collection', $v->{id}))}'>";
					print defined $v->{hyouji} && $v->{hyouji} && defined from_json($v->{hyouji})->{$Kahifu::Junbi::lang} && from_json($v->{hyouji})->{$Kahifu::Junbi::lang} ? midasi_settei(from_json($v->{hyouji})->{$Kahifu::Junbi::lang}) : midasi_settei($v->{midasi});
					print "</a>";
					print "</span>";
				print "</div>";
				print "<div class='count'>";
					print my $row_count = scalar(split(/,/,$v->{turu})), '件' if $v->{tag} ne 'yotei';
				print "</div>";
			print "</div>";
		}
		print "</div>"; #div.collection_box
	}
} elsif ($paginate == 3){
	#　PAGINATE=3
	#　履歴　RIREKI
	$rirekiran = $dbh->prepare($meirei[0]);
	$rirekiran->execute($week_limit_lower, $week_limit_upper, @sitazi_bind);
	print "<div class='rireki_box'>";
		my $last_sakuhin;
		while(my $v = $rirekiran->fetchrow_hashref){
			print "<div class='koumoku type_$v->{hantyuu}${\( sub { return ' hankakusi' if defined $v->{kakusu} && $v->{kakusu}==1 }->() )}'>";
				print "<div class='hiduke'>";
					print "<span>${\(date_split($v->{jiten}, 7))}</span>";
				print "</div>";
				print "<div class='sakuhinmei'>";
					print "<p id='$v->{id}' class='midasi $v->{id}' data-kansou='$v->{id}'>";
					print midasi_settei($v->{midasi}, $v->{mikakutei}, $v->{current}, $kensaku) if (defined $last_sakuhin && $last_sakuhin ne "" && $last_sakuhin ne $v->{sid}) || not defined $last_sakuhin;
					print "</p>";	
				print "</div>";
				print "<div class='jyou'>";
					print "<div class='jyoukyou' data-jyoutype='$v->{jyoukyou}' data-jyoukyou='$v->{id}'>";
						my $jyoukyou_syori = jyoukyou_settei($v->{jyoukyou}, 0, $v->{jiten}, 609, 609);
						print "<span class='jyoukyou_type_$jyoukyou_type{$jyoukyou_syori} $jyoukyou_class{$jyoukyou_syori}'>";
						print $jyoukyou_syori;
						print "</span>";
					print "</div>";
					print "<span class='jyouhou' data-jyouhou='$v->{id}'>";
					print $v->{part};
					print defined $v->{eternal} && $v->{eternal} == 1 ? "" : "／$v->{whole}";
					print $v->{josuu};
					print "</span>";
				print "</div>";
				print "<div class='bikou${\( sub { return ' ari' if defined $v->{text} && $v->{text} }->() )}'>";
					print $v->{text} if defined $v->{text} && $v->{text};
				print "</div>";
			print "</div>";
			$last_sakuhin = $v->{sid};
		}
		print "<div class='week'>";
		print "</div>";
	print "</div>";
	
	print "<script>
\$(function()
		{
		\$('div.navi > span').click(function()
		  {
			var span = \$(this);
			var text = ${week};
			var new_text = prompt(\"${\(Kahifu::Template::dict('WEEK_NUMBER'))}\", text);
			const params = new URLSearchParams(window.location.search);
			if (new_text != null && Number.isInteger(parseInt(text)) && new_text != text){
				params.set('week', new_text);
				window.location.search = params;
			}
		  });
		});	
	</script>";
}

print <<HTML
<script>
	\$(document).ready(function(){
		function getCookie(name) { 
	  	var cookies = '; ' + document.cookie; 
	  	var splitCookie = cookies.split('; ' + name + '='); 
	  	if (splitCookie.length == 2) return splitCookie.pop();
		}
		
		if(true){
			var current_class = \$('div.commander > div.migi > div.narabikae select:nth-of-type(1) option:selected').attr('class');
			\$('div.commander > div.migi > div.narabikae select:nth-of-type(1)').removeClass();
			\$('div.commander > div.migi > div.narabikae select:nth-of-type(1)').addClass(current_class);
			var current_class_2 = \$('.h_sakuhin select:nth-of-type(2) option:selected').attr('class');
			\$('div.commander > div.migi > div.narabikae select:nth-of-type(2)').removeClass();
			\$('div.commander > div.migi > div.narabikae select:nth-of-type(2)').addClass(current_class_2);
		}
 	});
	
	\$(document).on('change', 'div.commander > div.migi > div.narabikae select', function(){
		\$('#paginate_siborikomi').show();
 	});
 	
 	\$(document).on('change', 'div.commander > div.migi > div.narabikae select:nth-of-type(1)', function(){
		var current_class = \$('div.commander > div.migi > div.narabikae select:nth-of-type(1) option:selected').attr('class');
		\$('div.commander > div.migi > div.narabikae select:nth-of-type(1)').removeClass();
		\$('div.commander > div.migi > div.narabikae select:nth-of-type(1)').addClass(current_class);
	});
  	
	\$(document).on('change', 'div.commander > div.migi > div.narabikae select:nth-of-type(2)', function(){
		var current_class = \$('div.commander > div.migi > div.narabikae select:nth-of-type(2) option:selected').attr('class');
		\$('div.commander > div.migi > div.narabikae select:nth-of-type(2)').removeClass();
		\$('div.commander > div.migi > div.narabikae select:nth-of-type(2)').addClass(current_class);
	});

	\$('.theme').click(function() {
		var sheet = \$(this).attr('class').split(' ')[1];
		var now = new Date();
		var time = now.getTime();
		var expireTime = time + 10000000*36000;
		now.setTime(expireTime);
		document.cookie = 'hyouka_style='+sheet+';expires='+now.toUTCString()+';path=/;SameSite=Strict';	
		console.log("here");		
		\$("div[data-style]").click(function() {
			\$("head link#style").attr("href", \$(this).data("style"));
		});
	});
	
	var category_selected = 0;
	var state_selected = 0;
	
	if(document.cookie.split(";").some((item) => item.trim().startsWith("hyouka_category="))){
		category_selected = document.cookie.split("; ").find((row) => row.startsWith("hyouka_category="))?.split("=")[1];
	}
	
	if(document.cookie.split(";").some((item) => item.trim().startsWith("hyouka_state="))){
		state_selected = document.cookie.split("; ").find((row) => row.startsWith("hyouka_state="))?.split("=")[1];
	}
	
	if(category_selected != 0){
		\$('.hanrei.button div').removeClass('selected_category');
		\$(`.hanrei.button div[data-nokori='\${category_selected}']`).addClass('selected_category');
		\$('div[class^="koumoku type"]:visible').hide();
		\$('div[class^="colle koumoku type"]:visible').hide();
			var onokori = category_selected;
			var onokori_list = onokori.split(',');
			for (let index = 0; index < onokori_list.length; ++index) {
				const element = onokori_list[index];
				\$(`div[class\$="_\${element}"]`).show();
		}
	}
	
	if(state_selected != 0){
		\$('.hanrei.jyoukyou_itirann div').removeClass('selected_category');
		\$(`.hanrei.jyoukyou_itirann div[data-name='\${state_selected}']`).addClass('selected_category');
		\$('.koumoku > .jyou > .jyoukyou:visible').parents('.koumoku').hide().find(`[data-jyoutype='\${state_selected}']`).parents('.koumoku').show();
	}
	
	\$('.hanrei.button div').not('div[class^="hantyuu_all"]').click(function(){
		\$('.hanrei.button div').removeClass('selected_category');
		\$(this).addClass('selected_category');
		\$('div[class^="koumoku type"]:visible').hide();
		\$('div[class^="colle koumoku type"]:visible').hide();
		var onokori = \$(this).attr('data-nokori');
		var onokori_list = onokori.split(',');
		for (let index = 0; index < onokori_list.length; ++index) {
			const element = onokori_list[index];
			\$(`div[class*="_\${element}"]`).show();
		}
		category_selected = onokori;
		if(state_selected != 0){
			\$('.koumoku > .jyou > .jyoukyou:visible').parents('.koumoku').hide().find(`[data-jyoutype='\${state_selected}']`).parents('.koumoku').show();
		}
		
		var now = new Date();
		var time = now.getTime();
		var expireTime = time + 10000000*36000;
		now.setTime(expireTime);
		document.cookie = 'hyouka_category='+category_selected+';expires='+now.toUTCString()+';path=/;SameSite=Strict';		
	});
	
	\$('.hanrei.jyoukyou_itirann div').not('div[class^="jyoukyou all"]').click(function(){
		\$('.hanrei.jyoukyou_itirann div').removeClass('selected_category');
		\$(this).addClass('selected_category');
		var jyou = \$(this).attr('data-name');
		state_selected = jyou;
		if(category_selected != 0){
			\$('div[class^="koumoku type"]:visible').hide();
			\$('div[class^="colle koumoku type"]:visible').hide();
			var onokori = category_selected;
			var onokori_list = onokori.split(',');
			for (let index = 0; index < onokori_list.length; ++index) {
				const element = onokori_list[index];
				\$(`div[class*="_\${element}"]`).show();
			}
		}
		\$('.koumoku > .jyou > .jyoukyou:visible').parents('.koumoku').hide().find(`[data-jyoutype='\${jyou}']`).parents('.koumoku').show();
		
		var now = new Date();
		var time = now.getTime();
		var expireTime = time + 10000000*36000;
		now.setTime(expireTime);
		document.cookie = 'hyouka_state='+state_selected+';expires='+now.toUTCString()+';path=/;SameSite=Strict';	
	});
	
	\$('.hantyuu_all').click(function(){
		\$('.hanrei.button div').removeClass('selected_category');
		\$('div[class^="colle koumoku type"]').show();
		\$('div[class^="koumoku type"]').show();
		category_selected = 0;
		if(state_selected != 0){
			\$('.koumoku > .jyou > .jyoukyou:visible').parents('.koumoku').hide().find(`[data-jyoutype='\${state_selected}']`).parents('.koumoku').show();
		}
		
		var now = new Date();
		var time = now.getTime();
		var expireTime = time + 10000000*36000;
		now.setTime(expireTime);
		document.cookie = 'hyouka_category='+category_selected+';expires='+now.toUTCString()+';path=/;SameSite=Strict';	
	});
	
	\$('.jyoukyou.all').click(function(){
		\$('.hanrei.jyoukyou_itirann div').removeClass('selected_category');
		\$('div[class^="koumoku type"]').show();
		\$('div[class^="colle koumoku type"]').show();
		state_selected = 0;
		if(category_selected != 0){
			\$('div[class^="koumoku type"]:visible').hide();
			\$('div[class^="colle koumoku type"]:visible').hide();
			var onokori = category_selected;
			var onokori_list = onokori.split(',');
			for (let index = 0; index < onokori_list.length; ++index) {
				const element = onokori_list[index];
				\$(`div[class*="_\${element}"]`).show();
			}
		}
		
		var now = new Date();
		var time = now.getTime();
		var expireTime = time + 10000000*36000;
		now.setTime(expireTime);
		document.cookie = 'hyouka_state='+state_selected+';expires='+now.toUTCString()+';path=/;SameSite=Strict';	
	});

\$(function() {
  \$('.jyoukyou').on('click', function() {
	\$(".activity.active").add('#a_' + \$(this).attr('data-jyoukyou')).toggleClass('active');
  });
  \$('.jyouhou').on('click', function() {
	\$(".activity_kousin.active").add('#ak_' + \$(this).attr('data-jyouhou')).toggleClass('active');
  });
  \$('.ten').on('click', function() {
	\$(".ten_kousin.active").add('#tk_' + \$(this).attr('data-ten')).toggleClass('active');
  });
  \$('.midasi').on('click', function() {
	\$(".kansou_kousin.active").add('#kk_' + \$(this).attr('data-kansou')).toggleClass('active');
  });
});
</script>
HTML
;
# html>exeunt
print Kahifu::Template::html_noti();