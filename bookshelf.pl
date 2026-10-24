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
use Hyouka::Infra qw(jyoukyou_settei date date_split url_get_tuke url_get_hazusi);

my $uri = Kahifu::Template::fetch_uri(__FILE__);
my $ami = Kahifu::Template::fetch_ami($uri);

my %cookie = CGI::Cookie->fetch;
my $query = CGI->new;
my %url_get = $query->Vars();

our $ninsyou = (defined $cookie{kangeiroku_ninsyou} && unpack('H*', sha256($cookie{kangeiroku_ninsyou})) == Kahifu::Key::hyouka_sesame) || Kahifu::Template::tenmei;
my $dbh = Kahifu::Setuzoku::sql('kangeiroku');

my $count_sitami = $dbh->prepare("select `id` from `library`");
$count_sitami->execute();
my $syosekisuu = $count_sitami->rows();

my $page = (defined param('page') && param('page') != 1 && $ninsyou) ? param('page') : 1;
my $page_count = 100;
my $page_offset = ($page != 1) ? $page_count * (param('page')-1) : 0;

my $page_subete = ceil((($syosekisuu - $page_count) / $page_count) + 1);

my $meirei = "select * from `library` limit ?, ?";
my $syoseki_syutoku = $dbh->prepare($meirei);
$syoseki_syutoku->execute($page_offset, $page_count);
my $syoseki_page_total = $syoseki_syutoku->rows;

print "Content-type: text/html\n\n";

print Kahifu::Template::html_header($ami);
print "<link rel=\"stylesheet\" href=\"/chronicle/style/sumi.css\" />";
print "<link rel=\"stylesheet\" href=\"/chronicle/style/keitai.css\" />" if Kahifu::Infra::mobile();
print Kahifu::Template::html_saki("${\(Kahifu::Template::dict('HYOUKA_TITLE'))}<span>${\(Kahifu::Template::dict('EIGOYOU_KUUHAKU'))}${\(Kahifu::Template::dict('HYOUKA_SUBTITLE'))}</span>", undef, "Hyouka", 0);
# html>enter

my (%jyoukyou_type, %jyoukyou_class);
my $jyoukyou_list = $dbh->prepare("select * from `jyoukyou` where lib = 1");
$jyoukyou_list->execute();
while(my $v = $jyoukyou_list->fetchrow_hashref){
    print "<style>.jyoukyou_type_$v->{id} { color: hsla($v->{hsl}, 1); }.jyoukyou_type_alt_$v->{id} { color: hsla(${\(substr($v->{hsl}, 0, -3))}30%, 1); }</style>";
    $jyoukyou_type{$v->{jyoukyou}} = $v->{id};
    $jyoukyou_class{$v->{jyoukyou}} = $v->{class};
}

my ($echo);
print "<div class='navi'>";
    print "<a href='default.pl'>${\(Kahifu::Template::dict('MODORU'))}</a>";
    $echo .= "<a href='${\(url_get_tuke(\%url_get, 'page', ${\($page-1)}))}'>←</a>" if $page != 1;
    $echo .= "<span class='navi'>";
    $echo .= "page ";
    $echo .= my $page = (defined param('page')) ? param('page') : 1;
    $echo .= "${\(Kahifu::Template::dict('SLASH'))}";
    $echo .= $page_subete;
    $echo .= "</span>";
    $echo .= "<a class='migi' href='${\(url_get_tuke(\%url_get, 'page', ${\($page+1)}))}'>→</a>" if $page + 1 <= $page_subete;
    print $echo;
print "</div>";
print "<div class='hondana'>";
my $i;
while(my $v = $syoseki_syutoku->fetchrow_hashref){
    print "<div class='dann'>" if (Kahifu::Infra::mobile && $i % 10 == 0) || (!Kahifu::Infra::mobile && $i % 20 == 0);
        print "<div class='syoseki' style='${\( defined $v->{color} ? \"color: hsl($v->{color});fill: hsl($v->{color});\" : (defined $v->{haikei} ? '' : (((Kahifu::Infra::sitei_rand($v->{sakka}, 100)/100)**2)*100 > 55 ? 'color: black;fill: black;' : 'color: white;fill: white;') ) )}${\(defined $v->{haikei} ? \"background-color: hsl($v->{haikei});\" : \"background-color: hsl(${\(Kahifu::Infra::sitei_rand($v->{sakka}, 360))}, ${\(((Kahifu::Infra::sitei_rand($v->{sakka}, 100)/100)**2)*100)}%, ${\(((Kahifu::Infra::sitei_rand($v->{sakka}, 100)/100)**2)*100)}%);\")}'>";
            my @sakka_turu = split ';', $v->{sakka};
            (my $midasi = $v->{item}) =~ tr/0-9/０-９/;
            (my $sakka = $sakka_turu[0]) =~ tr/0-9/０-９/;
            
            my $count = () = $v->{item} =~ /[^a-zA-Z0-9\(\)]/g;
            my $count_sakka = () = $sakka =~ /[^a-zA-Z0-9\(\)]/g;

            if($count_sakka > 7){
                $sakka =~ s/.*・//;
                $count_sakka = length($sakka);
            }

            $sakka = $sakka . ' 他' if scalar @sakka_turu > 1;

            print "<div class='midasi count_$count'>";
                print "<svg xmlns:xhtml='http://www.w3.org/2000/xhtml' class='midasi' width='20' height='${\($count>6 && $v->{item} =~ /[\p{Han}\p{Hiragana}\p{Katakana}]/ ? min(200, ($count*4)+100) : ($v->{item} =~ /[\p{Han}\p{Hiragana}\p{Katakana}]/ ? '100' : '200') )}'>
                    <text x='0' y='0' dominant-baseline='text-bottom' textLength='${\($count>6 && $v->{item} =~ /[\p{Han}\p{Hiragana}\p{Katakana}]/ ? min(200, ($count*4)+100) : ($v->{item} =~ /[\p{Han}\p{Hiragana}\p{Katakana}]/ ? '100' : '') )}px' lengthAdjust='spacing${\(length($v->{item})>6 && $v->{item} =~ /[\p{Han}\p{Hiragana}\p{Katakana}]/ ? 'AndGlyphs' : '')}'>$midasi</text></svg>";
            print "</div>";
            print "<div class='sakka count_$count_sakka'>";
                print "<svg xmlns:xhtml='http://www.w3.org/2000/xhtml' class='sakka' width='20' height='${\($count_sakka>5 && $v->{sakka} =~ /(?![＝訳著編])[\p{Han}\p{Hiragana}\p{Katakana}]/ ? min(140, ($count_sakka*2.5)+80) : ($v->{sakka} =~ /(?![＝訳著編])[\p{Han}\p{Hiragana}\p{Katakana}]/ ? '80' : ($v->{sakka} eq '' ? '80' : '140') ) )}'>
                    <text x='0' y='0' dominant-baseline='text-bottom' textLength='${\($count_sakka>5 && $v->{sakka} =~ /(?![＝訳著編])[\p{Han}\p{Hiragana}\p{Katakana}]/ ? min(140, ($count_sakka*2.5)+80) : ($v->{sakka} =~ /(?![＝訳著編])[\p{Han}\p{Hiragana}\p{Katakana}]/ ? '80' : '') )}px' lengthAdjust='spacing${\(length($sakka)>5 && $v->{sakka} =~ /(?![＝訳著編])[\p{Han}\p{Hiragana}\p{Katakana}]/ ? 'AndGlyphs' : '')}'>$sakka</text>
                </svg>";
            print "</div>";
            print "<div class='jyouhou'>";
			    my (@turu, $turu_sitazi);
                @turu = split /,/,$v->{turu};
                for(my $i=0; $i<scalar(@turu); $i++){$turu_sitazi .= '?,'}
                $turu_sitazi =~ s/,\s*$//; #　後端のコンマを削除す
                $turu_sitazi = '0' if not defined $turu_sitazi;
                my $sakuhin_meirei = ("select * from sakuhin where `id` in (${turu_sitazi})");
                my $sakuhin_syutoku = $dbh->prepare($sakuhin_meirei);
		        $sakuhin_syutoku->execute(@turu);
                my ($sakuhin_count, $sakuhin_kansousuu);
                while (my $v = $sakuhin_syutoku->fetchrow_hashref){
                    $sakuhin_count = $sakuhin_count + 1;
                    $sakuhin_kansousuu = $sakuhin_kansousuu + 1 if grep{$_ eq $v->{jyoukyou}} '終', '没', '再';
                }
                print "<div class='jyoukyoubako'><span class='jyoukyou_type_alt_${\( defined $sakuhin_count && $sakuhin_count >= 1 ? (defined $sakuhin_count && $sakuhin_kansousuu == $sakuhin_count ? 2 : 10) : 4 )}'>${\(Kahifu::Template::dict('HYOUKA_JYOUKYOU_' . (defined $sakuhin_count && $sakuhin_count >= 1 ? (defined $sakuhin_count && $sakuhin_kansousuu == $sakuhin_count ? 2 : 10) : 4 ))  )}</span></div>";
                print "<div class='sinkou'>";
                    print "<div class='part'>$sakuhin_kansousuu</div>" if defined $sakuhin_kansousuu;
                    print "<div class='whole'>$sakuhin_count</div>" if defined $sakuhin_count;
                print "</div>";
            print "</div>";
            print "<div class='hid'>";
                print "<span>$v->{id}</span>";
            print "</div>";
        print "</div>";
    print "</div>" if (Kahifu::Infra::mobile && $i % 10 == 9) || (!Kahifu::Infra::mobile && $i % 20 == 19);
    $i = $i + 1;
}
    print "</div>" if (Kahifu::Infra::mobile && $syoseki_page_total % 10 != 0) || (!Kahifu::Infra::mobile && $syoseki_page_total % 20 != 0);
print "</div>";

print "<script>
\$(function()
        {
        \$('div.navi > span').click(function()
            {
            var span = \$(this);
            var text = ${page};
            var new_text = prompt(\"${\(Kahifu::Template::dict('PAGE_NUMBER'))}\", text);
            const params = new URLSearchParams(window.location.search);
            if (new_text != null && Number.isInteger(parseInt(text)) && new_text != text){
                params.set('page', new_text);
                window.location.search = params;
            }
            });
        });	
    </script>";

# html>exeunt
print Kahifu::Template::html_noti();