#!/usr/bin/perl
use strict;
use warnings;

use open qw( :std :encoding(utf8) );
use utf8;
use CGI ":standard";
use CGI::Carp qw(warningsToBrowser fatalsToBrowser);
use lib qw(/var/www/html/heart/mod);
use Unicode::Japanese;
use Encode;
use Data::Dump qw(dump);
use List::Util qw(min max);

use Kahifu::Junbi;
use Kahifu::Template qw{dict};

my $uri = Kahifu::Template::fetch_uri(__FILE__);
my $ami = Kahifu::Template::fetch_ami($uri);

my %cookie = CGI::Cookie->fetch;

our $ninsyou = (defined $cookie{kangeiroku_ninsyou} && unpack('H*', sha256($cookie{kangeiroku_ninsyou})) == Kahifu::Key::hyouka_sesame) || Kahifu::Template::tenmei;
my $dbh = Kahifu::Setuzoku::sql('kangeiroku');

my $page = (defined param('page') && param('page') != 1 && $ninsyou) ? param('page') : 1;
my $page_count = 200;
my $page_offset = ($page != 1) ? $page_count * (param('page')-1) : 0;

my $meirei = "select * from `library` limit ?, ?";
my $syoseki_syutoku = $dbh->prepare($meirei);
$syoseki_syutoku->execute($page_offset, $page_count);

print "Content-type: text/html\n\n";

print Kahifu::Template::html_header($ami);
print "<link rel=\"stylesheet\" href=\"/chronicle/style/sumi.css\" />";
print Kahifu::Template::html_saki("${\(Kahifu::Template::dict('HYOUKA_TITLE'))}<span>${\(Kahifu::Template::dict('EIGOYOU_KUUHAKU'))}${\(Kahifu::Template::dict('HYOUKA_SUBTITLE'))}</span>", undef, "Hyouka", 0);
# html>enter

print "<div class='hondana'>";
my $i;
while(my $v = $syoseki_syutoku->fetchrow_hashref){
    print "<div>" if $i % 20 == 0;
        print "<div>";
        #(my $midasi = $v->{item}) =~ s/(\d{1,4})($|[^A-Za-z])/<foreignObject width='16' height='16'><xhtml:span class=\"suuji\">$1<\/xhtml:span><\/foreignObject>$2/g;
        #(my $sakka = $v->{sakka}) =~ s/(\d{1,4})($|[^A-Za-z])/<foreignObject x='0' y='0' width='100%' height='16'><xhtml:span class=\"suuji\">$1<\/xhtml:span><\/foreignObject>$2/g;
        (my $midasi = $v->{item}) =~ tr/0-9/０-９/;
        (my $sakka = $v->{sakka}) =~ tr/0-9/０-９/;
        my $count = () = $v->{item} =~ /[^a-zA-Z0-9]/g;
        #my $midasi = decode_utf8(Unicode::Japanese->new($v->{item})->h2z->get);
        #my $sakka = decode_utf8(Unicode::Japanese->new($v->{sakka})->h2z->get);
        #print "<span class='midasi'>$midasi</span>";
        #print "<span class='sakka'>$sakka</span>";
            print "<div class='midasi'>";
                print "<svg xmlns:xhtml='http://www.w3.org/2000/xhtml' class='midasi' width='100%' height='${\(length($v->{item})>6 ? min(200, ($count*5)+100) : '100')}'>
                    <text x='50%' y='0' textLength='${\($count>6 ? min(200, ($count*5)+100) : '100')}px' lengthAdjust='spacing${\(length($v->{item})>6 ? 'AndGlyphs' : '')}'>$midasi</text>
                </svg>";
            print "</div>";
            print "<div class='sakka'>";
                print "<span>$v->{sakka}</span>";
            print "</div>";
        print "</div>";
    print "</div>" if $i % 20 == 19;
    $i = $i + 1;
}
print "</div>";

# html>exeunt
print Kahifu::Template::html_noti();