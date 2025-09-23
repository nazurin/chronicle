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

if(request_method eq 'POST' && defined param('kansou_sousin') && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
	#my %cookie = CGI::Cookie->fetch;
	#my $query = CGI->new;
	#my @title_post = $query->param;
	#print dump @title_post;	
	
	my $text = decode_utf8(param('text'));	
	my $jiten = time();
	my $char = length($text);
	my $sounyuu_query = "insert into kansou_rireki (`sid`, `jiten`, `char`, `text`) values (?, ?, ?, ?)";
	my $sounyuu_jikkou = $dbh->prepare($sounyuu_query);
	$sounyuu_jikkou->execute(param('reference'), $jiten, $char, $text);
	
	my $info_sitami_query = "select count(*) as count, sid from kansou_long where sid = ? order by jiten desc limit 1";
	my $info_sitami_syutoku = $dbh->prepare($info_sitami_query);
	$info_sitami_syutoku->execute(param('reference'));
	my $info_sitami = $info_sitami_syutoku->fetchall_hashref('sid');
	
	if($info_sitami->{param('reference')}{count} == 0){
		my $dainiji_sounyuu_query = "insert into kansou_long (`sid`, `jiten`, `kansou`) values (?, ?, ?)";
		my $dainiji_sounyuu_jikkou = $dbh->prepare($dainiji_sounyuu_query);
		$dainiji_sounyuu_jikkou->execute(param('reference'), $jiten, $text);	
	} else {
		my $dainiji_sounyuu_query = "update kansou_long set jiten = ?, kansou = ? where sid = ?";
		my $dainiji_sounyuu_jikkou = $dbh->prepare($dainiji_sounyuu_query);
		$dainiji_sounyuu_jikkou->execute($jiten, $text, param('reference'));	
	}
}

if(request_method eq 'POST' && defined param('rireki_sousin') && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');

	my @rireki_sid = param('reference');	
	my $rireki_sid_placeholders = join ", ", ("?") x @rireki_sid;

	my $info_rireki_query = "select * from rireki where id in (${rireki_sid_placeholders})";
	my $info_rireki_syutoku = $dbh->prepare($info_rireki_query);
	$info_rireki_syutoku->execute(@rireki_sid);
	my $info_rireki = $info_rireki_syutoku->fetchall_hashref('id');

	my %params;
	foreach (param) {
		$params{$_} = [ param($_) ];
		$params{$_} = $params{$_}[0] if @{$params{$_}} == 1;
	}
	#die dump $params{'jiten_s'}[3];

	for(my $i = 0; $i < scalar(param('reference')); $i++){
		my $jiten = ref($params{'reference'}) eq 'ARRAY' ? ($params{'jiten_unix'}[$i] ne '' ? $params{'jiten_unix'}[$i] : ($params{'jiten_y'}[$i].$params{'jiten_m'}[$i].$params{'jiten_d'}[$i].$params{'jiten_h'}[$i].$params{'jiten_i'}[$i].$params{'jiten_s'}[$i] ne "" ? timestamp_syutoku($params{'jiten_y'}[$i], $params{'jiten_m'}[$i], $params{'jiten_d'}[$i], $params{'jiten_h'}[$i], $params{'jiten_i'}[$i], $params{'jiten_s'}[$i]) : $info_rireki->{$rireki_sid[$i]}{jiten})) : ($params{'jiten_unix'} ne '' ? $params{'jiten_unix'} : ($params{'jiten_y'}.$params{'jiten_m'}.$params{'jiten_d'}.$params{'jiten_h'}.$params{'jiten_i'}.$params{'jiten_s'} ne "" ? timestamp_syutoku($params{'jiten_y'}, $params{'jiten_m'}, $params{'jiten_d'}, $params{'jiten_h'}, $params{'jiten_i'}, $params{'jiten_s'}) : $info_rireki->{$rireki_sid[$i]}{jiten}));

		my $part_kousin = defined param('part') && param('part') ne '' ? (ref($params{'reference'}) eq 'ARRAY' ? decode_utf8($params{'part'}[$i]) : decode_utf8($params{'part'})) : $info_rireki->{$rireki_sid[$i]}{part};
		my $whole_kousin = defined param('whole') && param('whole') ne '' ? (ref($params{'reference'}) eq 'ARRAY' ? decode_utf8($params{'whole'}[$i]) : decode_utf8($params{'whole'})) : $info_rireki->{$rireki_sid[$i]}{whole};
		my $jyoukyou_kousin = defined param('jyoukyou') && param('jyoukyou') ne '' ? (ref($params{'reference'}) eq 'ARRAY' ? decode_utf8($params{'jyoukyou'}[$i]) : decode_utf8($params{'jyoukyou'})) : $info_rireki->{$rireki_sid[$i]}{jyoukyou};
		my $josuu_kousin = defined param('josuu') && param('josuu') ne '' ? (ref($params{'reference'}) eq 'ARRAY' ? decode_utf8($params{'josuu'}[$i]) : decode_utf8($params{'josuu'})) : $info_rireki->{$rireki_sid[$i]}{josuu};
		my $mikakutei_kousin = defined param('mikakutei') && param('mikakutei') ne '' ? (ref($params{'reference'}) eq 'ARRAY' ? decode_utf8($params{'mikakutei'}[$i]) : decode_utf8($params{'mikakutei'})) : $info_rireki->{$rireki_sid[$i]}{mkt};
		my $text_kousin = defined $params{'text'} && $params{'text'} ne '' ? (ref($params{'reference'}) eq 'ARRAY' ? decode_utf8($params{'text'}[$i]) : decode_utf8($params{'text'})) : $info_rireki->{$rireki_sid[$i]}{text};

		my $rireki_kousin_query = "update rireki set jiten = ?, part = ?, whole = ?, jyoukyou = ?, josuu = ?, mkt = ?, text = ? where id = ?";
		my $rireki_kousin_jikkou = $dbh->prepare($rireki_kousin_query);
		$rireki_kousin_jikkou->execute($jiten, $part_kousin, $whole_kousin, $jyoukyou_kousin, $josuu_kousin, $mikakutei_kousin, $text_kousin, $rireki_sid[$i]);	
	}
}

if(request_method eq 'POST' && defined param('kutikomi_sousin') && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
	my $text = decode_utf8(param('kutikomi'));	
	my $syurui = decode_utf8(param('syurui'));	
	my $jiten = time();
	my $sounyuu_query = "insert into kutikomi (`sid`, `jiten`, `syurui`, `text`) values (?, ?, ?, ?)";
	my $sounyuu_jikkou = $dbh->prepare($sounyuu_query);
	$sounyuu_jikkou->execute(param('reference'), $jiten, $syurui, $text);
}

if(request_method eq 'POST' && defined param('kutikomi_hensyuu') && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
	my $text = decode_utf8(param('kutikomi'));	
	my $kutikomi_id = decode_utf8(param('kutikomi_id'));	
	my $syurui = decode_utf8(param('syurui'));	
	my $jiten = decode_utf8(param('jiten'));
	my $sounyuu_query = "update kutikomi set `jiten` = ?, `syurui` = ?, `text` = ? where id = ?";
	my $sounyuu_jikkou = $dbh->prepare($sounyuu_query);
	$sounyuu_jikkou->execute($jiten, $syurui, $text, $kutikomi_id);
}

if(request_method eq 'POST' && defined param('kutikomi_ingen') && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
	my $kutikomi_id = decode_utf8(param('kutikomi_id'));	
	my $ingen_query = "update kutikomi set `kakusu` = !`kakusu` where id = ?";
	my $ingen_jikkou = $dbh->prepare($ingen_query);
	$ingen_jikkou->execute($kutikomi_id);
}

if(request_method eq 'POST' && defined param('kutikomi_sakujyo') && Kahifu::Template::tenmei()){
	my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
	my $kutikomi_id = decode_utf8(param('kutikomi_id'));	
	my $sakujyo_query = "delete from kutikomi where id = ?";
	my $sakujyo_jikkou = $dbh->prepare($sakujyo_query);
	$sakujyo_jikkou->execute($kutikomi_id);
}

my $query=new CGI;
print $query->redirect($ENV{HTTP_REFERER});
print "Content-type: text/html; charset=utf-8\n\n";