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

my $query=new CGI;
print $query->redirect($ENV{HTTP_REFERER});
print "Content-type: text/html; charset=utf-8\n\n";