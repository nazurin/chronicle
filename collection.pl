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
use Kahifu::Infra;
use Hyouka::Infra qw(jyoukyou_settei midasi_settei sakka_settei date date_split url_get_tuke url_get_hazusi week week_border week_count week_delta hash_max_key timestamp_syutoku);

# https://fastapi.metacpan.org/source/ZMIJ/Array-Utils-0.5/Utils.pm
sub array_minus(\@\@) {
	my %e = map{ $_ => undef } @{$_[1]};
	return grep( ! exists( $e{$_} ), @{$_[0]} ); 
}

#print "Content-type: text/html; charset=utf-8\n\n";

if(request_method eq 'POST' && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
	my $query = CGI->new;
	my @title = $query->param;
	my %process_result;
	foreach(@title){
		Kahifu::Infra::sizumase(\%process_result, split /\//, $_) = param($_);
	}
	
	my $midasi = defined param('midasi') && param('midasi') ? decode_utf8(param('midasi')) : "";
	my $midasi_seisiki = defined param('midasi_seisiki') && param('midasi_seisiki') ? decode_utf8(param('midasi_seisiki')) : "";
	my $hyouji_ja = defined param('hyouji/ja') && param('hyouji/ja') ? decode_utf8(param('hyouji/ja')) : "";
	my $hyouji_en = defined param('hyouji/en') && param('hyouji/en') ? decode_utf8(param('hyouji/en')) : "";
	my $turu = defined param('turu') && param('turu') ? decode_utf8(param('turu')) : "";
	my $tag = defined param('tag') && param('tag') ? decode_utf8(param('tag')) : "";	
	my $gaiyouran = defined param('gaiyouran') && param('gaiyouran') ? decode_utf8(param('gaiyouran')) : "";	
	my $bikou = defined param('bikou') && param('bikou') ? decode_utf8(param('bikou')) : "";		
	my $hide = defined param('hide') && param('hide') ? decode_utf8(param('hide')) : 0;		
	my $bikouiti = defined param('bikouiti') && param('bikouiti') ? decode_utf8(param('bikouiti')) : 0;
	my $kansou_hyouji = defined param('kansou_hyouji') && param('kansou_hyouji') ? decode_utf8(param('kansou_hyouji')) : 0;		
	
	my $jiten = time();
	
	my $hyouji = decode_utf8(to_json($process_result{hyouji}));
	
	my $color_sitami_query = "select hantyuu, count(*) as `count` from sakuhin where id in (?) group by `hantyuu` order by count desc limit 1";
	my $color_sitami = $dbh->prepare($color_sitami_query);
	$color_sitami->execute($turu);
	my $color;
	while(my $v = $color_sitami->fetchrow_arrayref){
		$color = $v->[0];
	}
	
	my %bikou_sousin;
	for my $i (split '\+\+', $bikou){
		my @bikou_gyou_raw = split '\:\:', $i;
		my $bikou_gyou_key = $bikou_gyou_raw[0];
		$bikou_gyou_key =~ s/\R//g;
		my $bikou_gyou_value = $bikou_gyou_raw[1];
		$bikou_gyou_value =~ s/\R//g;
		$bikou_sousin{$bikou_gyou_key} = $bikou_gyou_value if defined $bikou_gyou_value;
	}
	my $bikou_serialized = to_json(\%bikou_sousin);
	
	if(defined param('colle_sinkiroku')){
		print "Yes!";
		my $query = "insert into collection set midasi = ?, midasi_seisiki = ?, hyouji = ?, turu = ?, tag = ?, gaiyouran = ?, bikou = ?, kakusu = ?, bikouiti = ?, kansou_hyouji = ?, jiten = ?, color = ?";
		my $sinkiroku = $dbh->prepare($query);
		$sinkiroku->execute($midasi, $midasi_seisiki, $hyouji, $turu, $tag, $gaiyouran, $bikou_serialized, $hide, $bikouiti, $kansou_hyouji, $jiten, $color);
	} elsif(defined param('colle_hensyuu')){
		print "Yes!!";
		my $query = "update collection set midasi = ?, midasi_seisiki = ?, hyouji = ?, turu = ?, tag = ?, gaiyouran = ?, bikou = ?, kakusu = ?, bikouiti = ?, kansou_hyouji = ?, color = ? where midasi_seisiki = ?";
		my $hensyuu = $dbh->prepare($query);
		$hensyuu->execute($midasi, $midasi_seisiki, $hyouji, $turu, $tag, $gaiyouran, $bikou_serialized, $hide, $bikouiti, $kansou_hyouji, $color, $midasi_seisiki);
	}

	for my $i (split ',', $turu){
		my $info_query = "select `id`, `colle` from sakuhin where id = ?";
		my $info_syutoku = $dbh->prepare($info_query);
		$info_syutoku->execute($i);
		my $info = $info_syutoku->fetchall_hashref('id');
		my @colle_prev = split(',', $info->{$i}{'colle'});
		my @colle_current = split(',', $info->{$i}{'colle'});
		push(@colle_current, $midasi_seisiki);

		my @colle_list_get = $dbh->selectall_array("select midasi_seisiki from collection");
		for(my $i=0; $i<scalar(@colle_list_get); $i++){$colle_list_get[$i] = $colle_list_get[$i][0]}
		my %to_delete = map { $_ => 1 } @colle_list_get;
		@colle_current = grep { $to_delete{$_} } @colle_current;

		my @colle_tuke = array_minus(@colle_current, @colle_prev);
		my @colle_hazusi = array_minus(@colle_prev, @colle_current);
		my $colle_turu = join(',', @colle_current);
		my $sakuhin_query = "update sakuhin set colle = ? where id = ?";
		my $sakuhin_hensyuu = $dbh->prepare($sakuhin_query);
		$sakuhin_hensyuu->execute($colle_turu, $i);
	}
}

my $query=new CGI;
print $query->redirect($ENV{HTTP_REFERER});
print "Content-type: text/html; charset=utf-8\n\n";