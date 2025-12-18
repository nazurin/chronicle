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
use List::Util 'sum';
use JSON;
use open qw( :std :encoding(utf8) );
use utf8;
use Encode qw( decode_utf8 );
use POSIX;
use Digest::SHA qw( sha256 );

use Kahifu::Junbi;
use Kahifu::Template qw{dict};
use Kahifu::Setuzoku;
use Kahifu::Key;
use Hyouka::Infra qw(jyoukyou_settei midasi_settei sakka_settei midasi_tekisetuka date date_split url_get_tuke url_get_hazusi week week_border week_count week_delta hash_max_key color_makase image_makase ten_henkan config_syutoku);

my $uri = Kahifu::Template::fetch_uri(__FILE__);
my $ami = Kahifu::Template::fetch_ami($uri);

my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
my %cookie = CGI::Cookie->fetch;
my $query = CGI->new;
my @title_post = $query->param;
my %url_get = $query->Vars();

our $ninsyou = (defined $cookie{kangeiroku_ninsyou} && unpack('H*', sha256($cookie{kangeiroku_ninsyou})) == Kahifu::Key::hyouka_sesame) || Kahifu::Template::tenmei;

our $config = config_syutoku();
our $style = (defined $cookie{hyouka_style}) ? $cookie{hyouka_style}->value : $config->{style};

print "Content-type: text/html\n\n";

print Kahifu::Template::html_header($ami);
print "<link rel=\"stylesheet\" href=\"/chronicle/style/sumi.css\" />";
print "<link rel=\"stylesheet\" href=\"/chronicle/style/";
print $style;
print ".css\" />";
print "<link rel=\"stylesheet\" href=\"/chronicle/style/koten.css\" />";
print "<link rel=\"stylesheet\" href=\"/chronicle/style/keitai.css\" />" if Kahifu::Infra::mobile();
print Kahifu::Template::html_saki("${\(Kahifu::Template::dict('HYOUKA_TITLE'))}<span>${\(Kahifu::Template::dict('EIGOYOU_KUUHAKU'))}${\(Kahifu::Template::dict('HYOUKA_SUBTITLE'))}</span>", undef, "Hyouka");

sub fetch {
	my $dbh = shift;
	my $siteki = shift;
	my $lang = shift;
	my $kotoba = $dbh->prepare("select $lang from `tebiki` where `bunya` = ? limit 1");
	$kotoba->bind_param(1, $siteki);
	$kotoba->execute();
	return $kotoba->fetchrow_array;
}

# html>enter
print "<div class='heading'><span>${\(Kahifu::Template::dict('TEBIKI_FIRST'))}</span></div>";
print "<div class='body'><p>", Kahifu::Infra::bunsyou(fetch($dbh, "first", $Kahifu::Junbi::lang)), "</p></div>";

print "<div class='heading'><span>${\(Kahifu::Template::dict('TEBIKI_BUBUNMEISYOU'))}</span></div>";
print "<div class='subheading lang_$Kahifu::Junbi::lang'><span>${\(fetch($dbh, \"sub1\", $Kahifu::Junbi::lang))}</span></div>";
print "<div class='gazou'>";
print "<img src='${\(fetch($dbh, \"fig1\", $Kahifu::Junbi::lang))}'>";
print fetch($dbh, "svg1", $Kahifu::Junbi::lang);
print "</div>";
print "<div class='body'><p>", Kahifu::Infra::bunsyou(fetch($dbh, "dia1", $Kahifu::Junbi::lang)), "</p></div>";
print "<div class='subheading lang_$Kahifu::Junbi::lang'><span>${\(fetch($dbh, \"sub2\", $Kahifu::Junbi::lang))}</span></div>";
print "<div class='gazou'>";
print "<img src='${\(fetch($dbh, \"fig2\", $Kahifu::Junbi::lang))}'>";
print fetch($dbh, "svg2", $Kahifu::Junbi::lang);
print "</div>";
print "<div class='subheading lang_$Kahifu::Junbi::lang'><span>${\(fetch($dbh, \"sub3\", $Kahifu::Junbi::lang))}</span></div>";
print "<div class='gazou'>";
print "<img src='${\(fetch($dbh, \"fig3\", $Kahifu::Junbi::lang))}'>";
print fetch($dbh, "svg3", $Kahifu::Junbi::lang);
print "</div>";
# html>exeunt
print Kahifu::Template::html_noti();