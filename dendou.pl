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

if(request_method eq 'POST' && defined param('tuika') && Kahifu::Template::tenmei()){
    my $dbh = Kahifu::Setuzoku::sql('kangeiroku');

	my $bangou = defined param('bangou') && param('bangou') ? decode_utf8(param('bangou')) : undef;
	my $midasi_seisiki = defined param('midasi_seisiki') && param('midasi_seisiki') ? decode_utf8(param('midasi_seisiki')) : undef;
	my $pt = defined param('pt') && param('pt') ? decode_utf8(param('pt')) : undef;
	my $extra = defined param('extra') && param('extra') ? decode_utf8(param('extra')) : undef;
	my $text = defined param('text') && param('text') ? decode_utf8(param('text')) : undef;
    my $hajimari = param('tosi_hajimari').param('tuki_hajimari').param('hi_hajimari').param('ji_hajimari').param('fun_hajimari') ne "" ? timestamp_syutoku(param('tosi_hajimari'), param('tuki_hajimari'), param('hi_hajimari'), param('ji_hajimari'), param('fun_hajimari')) : (param('unix_hajimari') ne '' ? param('unix_hajimari') : time());

    my $meirei = "insert into dendou_rireki set sid = ?, midasi_seisiki = ?, pt = ?, extra = ?, text = ?, jiten = ?";
		
	my $sakuhin_insert = $dbh->prepare($meirei);
	$sakuhin_insert->execute($bangou, $midasi_seisiki, $pt, $extra, $text, $hajimari);
}

my $query=new CGI;
print $query->redirect($ENV{HTTP_REFERER});
print "Content-type: text/html; charset=utf-8\n\n";