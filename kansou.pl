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

# https://fastapi.metacpan.org/source/ZMIJ/Array-Utils-0.5/Utils.pm
sub array_diff(\@\@) {
	my %e = map { $_ => undef } @{$_[1]};
	return @{[ ( grep { (exists $e{$_}) ? ( delete $e{$_} ) : ( 1 ) } @{ $_[0] } ), keys %e ] };
}

# https://fastapi.metacpan.org/source/ZMIJ/Array-Utils-0.5/Utils.pm
sub array_minus(\@\@) {
	my %e = map{ $_ => undef } @{$_[1]};
	return grep( ! exists( $e{$_} ), @{$_[0]} ); 
}

#print "Content-type: text/html; charset=utf-8\n\n";

if(request_method eq 'POST' && Kahifu::Template::tenmei() && defined param('kousin') &&  (! defined param('kanri') || (defined param('kanri') && param('kanri') ne 'del'))){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');

	my %params;
	foreach (param) {
		$params{$_} = [ param($_) ];
		$params{$_} = $params{$_}[0] if @{$params{$_}} == 1;
	}
	
	my $id = defined param('reference') && param('reference') ? decode_utf8(param('reference')) : "";
	my $midasi = defined param('midasi') && param('midasi') ? decode_utf8(param('midasi')) : "";
	my $fukumidasi = defined param('fukumidasi') && param('fukumidasi') ? decode_utf8(param('fukumidasi')) : "";
	my $hantyuu_raw = defined param('hantyuu') && param('hantyuu') ? decode_utf8(param('hantyuu')) : "";
	my $sakka = defined param('sakka') && param('sakka') ? decode_utf8(param('sakka')) : "";
	my $colle = defined param('collection') && param('collection') ? decode_utf8(param('collection')) : "";	
	my @betumei_key = defined param('betumei_key') && param('betumei_key') ? decode_utf8(param('betumei_key')) : "";	
	my @betumei_val = defined param('betumei_val') && param('betumei_val') ? decode_utf8(param('betumei_val')) : "";	
	my @betumei_key_fuku = defined param('betumei_key_fuku') && param('betumei_key_fuku') ? decode_utf8(param('betumei_key_fuku')) : "";	
	my @betumei_val_fuku = defined param('betumei_val_fuku') && param('betumei_val_fuku') ? decode_utf8(param('betumei_val_fuku')) : "";	
	my @betumei_key_sakka = defined param('betumei_key_sakka') && param('betumei_key_sakka') ? decode_utf8(param('betumei_key_sakka')) : "";	
	my @betumei_val_sakka = defined param('betumei_val_sakka') && param('betumei_val_sakka') ? decode_utf8(param('betumei_val_sakka')) : "";	
	my $theme = defined param('theme') && param('theme') ? decode_utf8(param('theme')) : "";		
	my $gyousuu = defined param('gyousuu') && param('gyousuu') ? decode_utf8(param('gyousuu')) : 1;		
	my $current = defined param('current') && param('current') ? decode_utf8(param('current')) : 0;		
	my $eternal = defined param('eternal') && param('eternal') ? decode_utf8(param('eternal')) : 0;		
	my $haikei = defined param('bg_img') && param('bg_img') ? decode_utf8(param('bg_img')) : "";		
	my $mikakutei = defined param('mikakutei') && param('mikakutei') ? decode_utf8(param('mikakutei')) : 0;		
	my $kansou = defined param('kansou') && param('kansou') ? decode_utf8(param('kansou')) : "";		
	my $yotei = defined param('yotei') && param('yotei') ? decode_utf8(param('yotei')) : 0;		

	my $genzai = time();
	
	my $info_query = "select * from sakuhin where id = ?";
	my $info_syutoku = $dbh->prepare($info_query);
	$info_syutoku->execute(param('reference'));
	my $info = $info_syutoku->fetchall_hashref('id');

	my ($betumei, $fukubetumei, $sakkabetumei);
	foreach my $i (0 .. scalar @betumei_val){
		$betumei->{decode_utf8($params{'betumei_key'}->[$i])} = decode_utf8($params{'betumei_val'}->[$i]) if ref $params{'betumei_key'} eq 'ARRAY';
		$betumei->{decode_utf8($params{'betumei_key'})} = decode_utf8($params{'betumei_val'}) if ref $params{'betumei_key'} ne 'ARRAY';
	}
	my $betumei_json = to_json($betumei);
	foreach my $i (0 .. scalar @betumei_val_fuku){
		$fukubetumei->{decode_utf8($params{'betumei_key_fuku'}->[$i])} = decode_utf8($params{'betumei_val_fuku'}->[$i]) if ref $params{'betumei_key_fuku'} eq 'ARRAY';
		$fukubetumei->{decode_utf8($params{'betumei_key_fuku'})} = decode_utf8($params{'betumei_val_fuku'}) if ref $params{'betumei_key_fuku'} ne 'ARRAY';
	}
	my $fukubetumei_json = to_json($fukubetumei);
	foreach my $i (0 .. scalar @betumei_val_sakka){
		$sakkabetumei->{decode_utf8($params{'betumei_key_sakka'}->[$i])} = decode_utf8($params{'betumei_val_sakka'}->[$i]) if ref $params{'betumei_key_sakka'} eq 'ARRAY';
		$sakkabetumei->{decode_utf8($params{'betumei_key_sakka'})} = decode_utf8($params{'betumei_val_sakka'}) if ref $params{'betumei_key_sakka'} ne 'ARRAY';
	}
	my $sakkabetumei_json = to_json($sakkabetumei);
	
	my @colle_prev = split(',', $info->{$id}{colle});
	my @colle_current = split(',', $colle);
	
	my @colle_list_get = $dbh->selectall_array("select midasi_seisiki from collection");
	for(my $i=0; $i<scalar(@colle_list_get); $i++){$colle_list_get[$i] = $colle_list_get[$i][0]}
	my %to_delete = map { $_ => 1 } @colle_list_get;
	@colle_current = grep { $to_delete{$_} } @colle_current;
	
	my @colle_tuke = array_minus(@colle_current, @colle_prev);
	my @colle_hazusi = array_minus(@colle_prev, @colle_current);
	#die dump @colle_hazusi;
	my $colle_turu = join(',', @colle_current);
	#my $colle_turu_sitazi = scalar @colle_current > 0 ? ", colle = ?" : "";
		
	for my $i (@colle_hazusi){
		my @sitazi_bind;
		my $read_turu;
		my $turu_get_query = "select turu from collection where midasi_seisiki = ?";
		my $turu_get = $dbh->prepare($turu_get_query);
		$turu_get->execute($i);
		while(my $v = $turu_get->fetchrow_arrayref){
			$read_turu = $v->[0];
		}
		my @maki = split(',', $read_turu);
		@maki = grep {$_ ne $id} @maki;
		my $turu_new = join(',', @maki);
		# `turu` = concat(ifnull(`turu`,''), ?) ←更新する場合
		my $colle_settei = "update collection set `turu` = ? where `midasi_seisiki` = ?";
		my $colle_send = $dbh->prepare($colle_settei);
		$colle_send->execute($turu_new, @sitazi_bind, $i);
	}
	
	for my $i (@colle_tuke){
		my @sitazi_bind;
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
		my $colle_settei = "update collection set `turu` = ? where `midasi_seisiki` = ?";
		my $colle_send = $dbh->prepare($colle_settei);
		$colle_send->execute($turu_new, @sitazi_bind, $i);
	}
		
	my $hantyuu_get_query = "select hantyuu from hantyuu_alias where kotoba = ?";
	my $hantyuu_get = $dbh->prepare($hantyuu_get_query);
	$hantyuu_get->execute($hantyuu_raw);
	my $hantyuu;
	while(my $v = $hantyuu_get->fetchrow_arrayref){
		$hantyuu = $v->[0];
	}
	
	if($kansou ne $info->{$id}{kansou}){
		my $char = length($kansou);
		my $sounyuu_query = "insert into kansou_rireki_short (`sid`, `jiten`, `char`, `text`) values (?, ?, ?, ?)";
		my $sounyuu_jikkou = $dbh->prepare($sounyuu_query);
		$sounyuu_jikkou->execute($id, $genzai, $char, $kansou);
	}
		
	my $meirei = "update sakuhin set yotei = ?, midasi = ?, fukumidasi = ?, hantyuu = ?, sakka = ?, betumei = ?, fukubetumei = ?, sakkabetumei = ?, theme = ?, gyousuu = ?, bg_img = ?, eternal = ?, current = ?, kansou = ?, mikakutei = ?, colle = ? where id = ? ";
	
	my $sakuhin_kousin = $dbh->prepare($meirei);
	$sakuhin_kousin->execute($yotei, $midasi, $fukumidasi, $hantyuu, $sakka, $betumei_json, $fukubetumei_json, $sakkabetumei_json, $theme, $gyousuu, $haikei, $eternal, $current, $kansou, $mikakutei, $colle_turu, $id);
} elsif(request_method eq 'POST' && Kahifu::Template::tenmei() && defined param('kanri') && param('kanri') eq 'del') {
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
	
	my $id = defined param('reference') && param('reference') ? decode_utf8(param('reference')) : "";
	my $colle = defined param('collection') && param('collection') ? decode_utf8(param('collection')) : "";	
	
	my @colle_current = split(',', $colle);
	my @colle_list_get = $dbh->selectall_array("select midasi_seisiki from collection");
	for(my $i=0; $i<scalar(@colle_list_get); $i++){$colle_list_get[$i] = $colle_list_get[$i][0]}
	my %to_delete = map { $_ => 1 } @colle_list_get;
	@colle_current = grep { $to_delete{$_} } @colle_current;
	
	for my $i (@colle_current){
		my @sitazi_bind;
		my $read_turu;
		my $turu_get_query = "select turu from collection where midasi_seisiki = ?";
		my $turu_get = $dbh->prepare($turu_get_query);
		$turu_get->execute($i);
		while(my $v = $turu_get->fetchrow_arrayref){
			$read_turu = $v->[0];
		}
		my @maki = split(',', $read_turu);
		@maki = grep {$_ ne $id} @maki;
		my $turu_new = join(',', @maki);
		my $colle_settei = "update collection set `turu` = ? where `midasi_seisiki` = ?";
		my $colle_send = $dbh->prepare($colle_settei);
		$colle_send->execute($turu_new, @sitazi_bind, $i);
	}
	
	my $delete_sakuhin = "delete from sakuhin where `id` = ?";
	my $delete_sakuhin_jikkou = $dbh->prepare($delete_sakuhin);
	$delete_sakuhin_jikkou->execute($id);
}

my $query=new CGI;
print $query->redirect($ENV{HTTP_REFERER});
print "Content-type: text/html; charset=utf-8\n\n";