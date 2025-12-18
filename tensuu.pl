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

#print "Content-type: text/html; charset=utf-8\n\n";

if(request_method eq 'POST' && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
	my $id = defined param('reference') && param('reference') ? decode_utf8(param('reference')) : "";	
	my $jiten = time();
	
	my $info_sitami_query = "select id, hantyuu, part, josuu, jyoukyou, hajimari, owari, kakusu, point, mal_id, al_id, mal_pt, al_pt, bl_pt from sakuhin where id = ?";
	my $info_sitami_syutoku = $dbh->prepare($info_sitami_query);
	$info_sitami_syutoku->execute(param('reference'));
	my $info_sitami = $info_sitami_syutoku->fetchall_hashref('id');
	my $tensuu_kojin = $info_sitami->{param('reference')}{point};
	my $tensuu_mal_pt = $info_sitami->{param('reference')}{mal_pt};
	my $tensuu_al_pt = $info_sitami->{param('reference')}{al_pt};
	my $tensuu_bl_pt = $info_sitami->{param('reference')}{bl_pt};
	my $hantyuu = $info_sitami->{param('reference')}{hantyuu};
	my $mal_id = $info_sitami->{param('reference')}{mal_id};
	my $al_id = $info_sitami->{param('reference')}{al_id};
	# hard_kousin用
	my $part = $info_sitami->{param('reference')}{part};
	my $josuu = $info_sitami->{param('reference')}{josuu};
	my $jyoukyou = $info_sitami->{param('reference')}{jyoukyou};
	my $hajimari_y = date_split($info_sitami->{param('reference')}{hajimari}, 0);
	my $hajimari_m = date_split($info_sitami->{param('reference')}{hajimari}, 1);
	my $hajimari_d = date_split($info_sitami->{param('reference')}{hajimari}, 2);
	my $owari_y = date_split($info_sitami->{param('reference')}{owari}, 0);
	my $owari_m = date_split($info_sitami->{param('reference')}{owari}, 1);
	my $owari_d = date_split($info_sitami->{param('reference')}{owari}, 2);
	my $hajimari_ymd = date_split($info_sitami->{param('reference')}{hajimari}, 50);
	my $owari_ymd = date_split($info_sitami->{param('reference')}{owari}, 50);
	my $kakusu = defined $info_sitami->{param('reference')}{kakusu} && $info_sitami->{param('reference')}{kakusu} == 1 ? \1 : \0;

	my $param_tensuu_kojin = param('tensuu_kojin') ne '' ? decode_utf8(param('tensuu_kojin')) : undef;
	my @param_tensuu_mal_pt_turu = split /:/, param('tensuu_mal_pt');
	my $param_tensuu_mal_pt = $param_tensuu_mal_pt_turu[0] ne '' ? decode_utf8($param_tensuu_mal_pt_turu[0]) : undef;
	my @param_tensuu_al_pt_turu = split /:/, param('tensuu_al_pt');
	my $param_tensuu_al_pt = $param_tensuu_al_pt_turu[0] ne '' ? decode_utf8($param_tensuu_al_pt_turu[0]) : undef;
	my $hard_kousin_mal = $param_tensuu_mal_pt_turu[1] eq 'hard' ? 1 : 0;
	my $hard_kousin_al = $param_tensuu_al_pt_turu[1] eq 'hard' ? 1 : 0;
	my $param_tensuu_bl_pt = param('tensuu_bl_pt') ne '' ? decode_utf8(param('tensuu_bl_pt')) : undef;

	my (@sitazi_bind, $tensuu_sitazi);
	$tensuu_sitazi = "point = ?, mal_pt = ?, al_pt = ?, bl_pt = ?";
	push @sitazi_bind, ($param_tensuu_kojin, $param_tensuu_mal_pt, $param_tensuu_al_pt, $param_tensuu_bl_pt);

	my $sakuhin_kousin_query = "update `sakuhin` set ${tensuu_sitazi} where `id` = ?";
	my $sakuhin_kousin = $dbh->prepare($sakuhin_kousin_query);
	$sakuhin_kousin->execute(@sitazi_bind, $id);
	
	my $sakuhin_kousin_query = "insert into `tensuu_rireki` set ${tensuu_sitazi}, jiten = ?, sid = ?";
	my $sakuhin_kousin = $dbh->prepare($sakuhin_kousin_query);
	$sakuhin_kousin->execute(@sitazi_bind, $jiten, $id);

	my $api_json_data = Hyouka::External::api_json_syutoku();
	
	if(grep{$_ eq $hantyuu} 13, 14, 17){
		$hard_kousin_mal == 1 ? Hyouka::External::mal_hard_kousin($mal_id, $part, $josuu, $jyoukyou, $hantyuu, $hajimari_ymd, $owari_ymd, $param_tensuu_mal_pt, $api_json_data) : (defined $mal_pt ? Hyouka::External::mal_score_kousin($mal_id, $hantyuu, decode_utf8(param('tensuu_mal_pt')), $api_json_data) : "");
		$hard_kousin_al == 1 ? Hyouka::External::al_hard_kousin($al_id, $part, $josuu, $jyoukyou, $hajimari_y, $hajimari_m, $hajimari_d, $owari_y, $owari_m, $owari_d, $param_tensuu_al_pt, $kakusu, $api_json_data) : (defined $al_pt ? Hyouka::External::al_score_kousin($al_id, decode_utf8(param('tensuu_al_pt')), $api_json_data) : "");
	}
}

my $query=new CGI;
print $query->redirect($ENV{HTTP_REFERER});
print "Content-type: text/html; charset=utf-8\n\n";