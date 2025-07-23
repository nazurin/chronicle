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
	#my %cookie = CGI::Cookie->fetch;
	my $query = CGI->new;
	my @title_post = $query->param;
	my $turu = join ',', param('junban');
	my @array_junban = param('junban');
	my @bikou_naiyou = param('test');
	my $id = param('collection');	
	
	my %bikou_sousin;
	for(my $i = 0; $i < scalar(param('junban')); $i++){
		$bikou_sousin{$array_junban[$i]} = decode_utf8($bikou_naiyou[$i]);
	}
	delete($bikou_sousin{""});
	my $bikou_serialized = to_json(\%bikou_sousin);

	my $saisettei_query = "update collection set turu = ?, bikou = ? where id = ?";
	my $saisettei_kousin = $dbh->prepare($saisettei_query);
	$saisettei_kousin->execute($turu, $bikou_serialized, $id);
}

my $query=new CGI;
print $query->redirect($ENV{HTTP_REFERER});
print "Content-type: text/html; charset=utf-8\n\n";