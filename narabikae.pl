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
	
	for my $i (0 .. scalar(@bikou_naiyou) - 1){
		$bikou_naiyou[$i] = decode_utf8($bikou_naiyou[$i]);
	}
	if(defined(param('jidou_hiduke_sort'))){
		my @leading_bikou_naiyou;
		for my $i (0 .. scalar @array_junban - 1){
			my $tosi = substr($bikou_naiyou[$i], index($bikou_naiyou[$i], '年')-4, 4);
			my $tuki = (index($bikou_naiyou[$i], '月') - index($bikou_naiyou[$i], '年') == 2) ? 0 . substr($bikou_naiyou[$i], index($bikou_naiyou[$i], '月')-1, 1) : substr($bikou_naiyou[$i], index($bikou_naiyou[$i], '月')-2, 2);
			my $hi = (index($bikou_naiyou[$i], '日') - index($bikou_naiyou[$i], '月') == 2) ? 0 . substr($bikou_naiyou[$i], index($bikou_naiyou[$i], '日')-1, 1) : substr($bikou_naiyou[$i], index($bikou_naiyou[$i], '日')-2, 2);
			$leading_bikou_naiyou[$i] = $tosi . '-' . $tuki . '-' . $hi;
			# 先行ゼロを削除する
			$hi = substr($hi, 1) if substr($hi, 0, 1) eq '0';
			$tuki = substr($tuki, 1) if substr($tuki, 0, 1) eq '0';
			$bikou_naiyou[$i] = $tosi . '年' . $tuki . '月' . $hi . '日';
		}
		#die dump @leading_bikou_naiyou;
		my @sort_arrange = sort { $leading_bikou_naiyou[$a] cmp $leading_bikou_naiyou[$b] } 0 .. $#leading_bikou_naiyou;
		@array_junban = @array_junban[@sort_arrange];
		@bikou_naiyou = @bikou_naiyou[@sort_arrange];
		$turu = join ',', @array_junban;
	}

	my %bikou_sousin;
	for(my $i = 0; $i < scalar(@bikou_naiyou); $i++){
		$bikou_sousin{$array_junban[$i]} = $bikou_naiyou[$i];
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