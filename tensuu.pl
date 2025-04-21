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

#print "Content-type: text/html; charset=utf-8\n\n";

if(request_method eq 'POST' && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
	my $id = defined param('reference') && param('reference') ? decode_utf8(param('reference')) : "";	
	my $jiten = time();
	
	my $info_sitami_query = "select id, point, mal_pt, al_pt, bl_pt from sakuhin where id = ?";
	my $info_sitami_syutoku = $dbh->prepare($info_sitami_query);
	$info_sitami_syutoku->execute(param('reference'));
	my $info_sitami = $info_sitami_syutoku->fetchall_hashref('id');
	my $tensuu_kojin = $info_sitami->{param('reference')}{point};
	my $tensuu_mal_pt = $info_sitami->{param('reference')}{mal_pt};
	my $tensuu_al_pt = $info_sitami->{param('reference')}{al_pt};
	my $tensuu_bl_pt = $info_sitami->{param('reference')}{bl_pt};

	my (@sitazi_bind, $tensuu_kojin_sitazi, $tensuu_mal_pt_sitazi, $tensuu_al_pt_sitazi, $tensuu_bl_pt_sitazi);
	if(defined param('tensuu_kojin') && param('tensuu_kojin')){
		$tensuu_kojin_sitazi = "point = ?,";
		push @sitazi_bind, decode_utf8(param('tensuu_kojin'));
	}
	if(defined param('tensuu_mal_pt') && param('tensuu_mal_pt')){
		$tensuu_mal_pt_sitazi = "mal_pt = ?,";
		push @sitazi_bind, decode_utf8(param('tensuu_mal_pt'));
	}
	if(defined param('tensuu_al_pt') && param('tensuu_al_pt')){
		$tensuu_al_pt_sitazi = "al_pt = ?,";
		push @sitazi_bind, decode_utf8(param('tensuu_al_pt'));
	}
	if(defined param('tensuu_bl_pt') && param('tensuu_bl_pt')){
		$tensuu_bl_pt_sitazi = "mal_pt = ?,";
		push @sitazi_bind, decode_utf8(param('tensuu_bl_pt'));
	}

	if(
		((! defined $tensuu_kojin && defined param('tensuu_kojin')) || (defined $tensuu_kojin && defined param('tensuu_kojin') && $tensuu_kojin != decode_utf8(param('tensuu_kojin')))) ||
		((! defined $tensuu_mal_pt && defined param('tensuu_mal_pt')) || (defined $tensuu_mal_pt && defined param('tensuu_mal_pt') && $tensuu_mal_pt != decode_utf8(param('tensuu_mal_pt')))) ||
		((! defined $tensuu_al_pt && defined param('tensuu_al_pt')) || (defined $tensuu_al_pt && defined param('tensuu_al_pt') && $tensuu_al_pt != decode_utf8(param('tensuu_al_pt')))) ||
		((! defined $tensuu_bl_pt && defined param('tensuu_bl_pt')) || (defined $tensuu_bl_pt && defined param('tensuu_bl_pt') && $tensuu_bl_pt != decode_utf8(param('tensuu_bl_pt'))))
	){
		my $sakuhin_kousin_query = "update `sakuhin` set ${tensuu_kojin_sitazi} ${tensuu_mal_pt_sitazi} ${tensuu_al_pt_sitazi} ${tensuu_bl_pt_sitazi} betumei = betumei where `id` = ?";
		my $sakuhin_kousin = $dbh->prepare($sakuhin_kousin_query);
		$sakuhin_kousin->execute(@sitazi_bind, $id);
		
		my $sakuhin_kousin_query = "insert into `tensuu_rireki` set ${tensuu_kojin_sitazi} ${tensuu_mal_pt_sitazi} ${tensuu_al_pt_sitazi} ${tensuu_bl_pt_sitazi} jiten = ?, sid = ?";
		my $sakuhin_kousin = $dbh->prepare($sakuhin_kousin_query);
		$sakuhin_kousin->execute(@sitazi_bind, $jiten, $id);
	} else {
		#die 'Yes!!';
	}
}

my $query=new CGI;
print $query->redirect($ENV{HTTP_REFERER});
print "Content-type: text/html; charset=utf-8\n\n";