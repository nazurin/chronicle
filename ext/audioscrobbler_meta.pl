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

my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
my $meta_kousin_query = "update listen
    left join listen_meta b on (listen.artist = b.artist and listen.name = b.name and listen.album = b.album)
    left join listen_meta c on (listen.artist = c.artist and listen.name = c.name)
    left join listen_meta d on (listen.artist = d.artist and listen.album = d.album)
set
    listen.`release` = if(b.`release` is null, if(c.`release` is null, d.`release`, c.`release`), b.`release`),
    listen.`tag` = if(b.`genre` is null, if(c.`genre` is null, d.`genre`, c.`genre`), b.`genre`)
where
    listen.`date` >= ?";
my $meta_kousin = $dbh->prepare($meta_kousin_query);
$meta_kousin->execute($from_timestamp);

my $query=new CGI;
print $query->redirect("https://kahifu.net/chronicle/default.pl");
print "Content-type: text/html; charset=utf-8\n\n";