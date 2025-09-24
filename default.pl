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
use Hyouka::Infra qw(jyoukyou_settei midasi_settei sakka_settei date date_split url_get_tuke url_get_hazusi week week_border week_count week_delta hash_max_key color_makase image_makase ten_henkan);

my $uri = Kahifu::Template::fetch_uri(__FILE__);
my $ami = Kahifu::Template::fetch_ami($uri);

my $dbh = Kahifu::Setuzoku::sql('kangeiroku');
my %cookie = CGI::Cookie->fetch;
my $query = CGI->new;
my @title_post = $query->param;
my %url_get = $query->Vars();

if (request_method eq 'POST'){
	my $cookie_siborikomi_hantyuu = Kahifu::Infra::cookie_seisei('hyouka_siborikomi_hantyuu', param('page_siborikomi_hantyuu'));
	print "Set-Cookie: $cookie_siborikomi_hantyuu\n" if defined param('page_siborikomi_hantyuu');
	my $cookie_siborikomi_jyoukyou = Kahifu::Infra::cookie_seisei('hyouka_siborikomi_jyoukyou', param('page_siborikomi_jyoukyou'));
	print "Set-Cookie: $cookie_siborikomi_jyoukyou\n" if defined param('page_siborikomi_jyoukyou');
	my $cookie_narabi = Kahifu::Infra::cookie_seisei('hyouka_narabi', param('narabi'));
	print "Set-Cookie: $cookie_narabi\n" if defined param('narabi');
	my $cookie_jun = Kahifu::Infra::cookie_seisei('hyouka_jun', param('jun'));
	print "Set-Cookie: $cookie_jun\n" if defined param('jun');
	my $query=new CGI;
	
	delete($url_get{narabikae_kettei});
	delete($url_get{page_siborikomi_hantyuu});
	delete($url_get{page_siborikomi_jyoukyou});
	delete($url_get{narabi});
	delete($url_get{jun});
	
	if(defined param('paginate')){
		my $cookie_paginate_colle = Kahifu::Infra::cookie_seisei('hyouka_paginate', 1);
		print "Set-Cookie: $cookie_paginate_colle\n";
		delete($url_get{paginate});
		$uri = url_get_hazusi(\%url_get, 'paginate');
	} elsif(defined param('favorite')){
		my $cookie_paginate_colle = Kahifu::Infra::cookie_seisei('hyouka_paginate', 2);
		print "Set-Cookie: $cookie_paginate_colle\n";
		delete($url_get{favorite});
		$uri = url_get_hazusi(\%url_get, 'favorite');
	} elsif(defined param('rireki')){
		my $cookie_paginate_colle = Kahifu::Infra::cookie_seisei('hyouka_paginate', 3);
		print "Set-Cookie: $cookie_paginate_colle\n";
		delete($url_get{rireki});
		$uri = url_get_hazusi(\%url_get, 'rireki');
	}
	
	if(defined param('narabikae_kettei')){
		$uri = url_get_tuke(\%url_get, 'kensaku', decode_utf8(param('kensaku'))) if defined param('kensaku') && param('kensaku') ne '';
	} elsif (defined param('kaijyo')){
		delete($url_get{kaijyo});
		$uri = url_get_hazusi(\%url_get, 'kensaku');
	}
	print $query->redirect($uri);
}
our $ninsyou = (defined $cookie{kangeiroku_ninsyou} && unpack('H*', sha256($cookie{kangeiroku_ninsyou})) == Kahifu::Key::hyouka_sesame) || Kahifu::Template::tenmei;

our $style = (defined $cookie{hyouka_style}) ? $cookie{hyouka_style}->value : 'gokusaisiki';
our $narabi = (defined $cookie{hyouka_narabi}) ? $cookie{hyouka_narabi}->value : 1;
our $jun = (defined $cookie{hyouka_jun}) ? $cookie{hyouka_jun}->value : 0;
our $sitei_gengo = (defined $cookie{hyouka_gengo}) ? $cookie{hyouka_gengo}->value : 3;
our $siborikomi_hantyuu = (defined $cookie{hyouka_siborikomi_hantyuu}) ? $cookie{hyouka_siborikomi_hantyuu}->value : 50;
our $siborikomi_jyoukyou = (defined $cookie{hyouka_siborikomi_jyoukyou}) ? $cookie{hyouka_siborikomi_jyoukyou}->value : 1;
our $paginate = (defined $cookie{hyouka_paginate}) ? $cookie{hyouka_paginate}->value : 1;
our $page = (defined param('page') && param('page') != 1 && $ninsyou) ? param('page') : 1;
our $page_offset = ($page != 1) ? 20 * (param('page')-1) : 0;
our $week = (defined param('week') && param('week') != 0 && $ninsyou) ? param('week') : 0;

my $imagenzai = time();
my $sanjyuujikan_seido = 1; # 0 = 24h, 1 = 30h
my @kisyuutoku_gengo = ('en', 'ja', 'fa', 'ur'); #grep{$_ eq @kisyuutoku_gengo} 4, 5

my $sanjyuujikansei_offset = $sanjyuujikan_seido * 21600;

print "Content-type: text/html; charset=utf-8\n\n";

print Kahifu::Template::html_header($ami);
print "<link rel=\"stylesheet\" href=\"/chronicle/style/sumi.css\" />";
print "<link rel=\"stylesheet\" href=\"/chronicle/style/";
print $style;
print ".css\" />";
print "<link rel=\"stylesheet\" href=\"/chronicle/style/keitai.css\" />" if Kahifu::Infra::mobile();
print "<script src='/heart/js/Sortable.min.js'></script>" if defined param('hensyuu') && $paginate == 2;
print "<script src='/heart/js/jquery-sortable.js'></script>" if defined param('hensyuu') && $paginate == 2;
print Kahifu::Template::html_saki("${\(Kahifu::Template::dict('HYOUKA_TITLE'))}<span>${\(Kahifu::Template::dict('EIGOYOU_KUUHAKU'))}${\(Kahifu::Template::dict('HYOUKA_SUBTITLE'))}</span>");

# html>enter 
#print @title_post;
#
#　さくひんの中
#　タグ、履歴、関連人物、なが感想などなど
#
#

print Kahifu::Junbi::lang;
if(defined param('id') && param('id')){
	my $sakuhin_query = "select * from sakuhin where id = ?";
	my $sakuhin_syutoku = $dbh->prepare($sakuhin_query);
	my $passthrough_id = param('id');
	$sakuhin_syutoku->execute($passthrough_id);
	my $sakuhin_info = $sakuhin_syutoku->fetchall_hashref('id');
	my @sakuhin_colle = split ',', $sakuhin_info->{$passthrough_id}{colle};
	my $colle_placeholders = join ", ", ("?") x @sakuhin_colle;
	my $seed = $sakuhin_info->{$passthrough_id}{time};
	print "<div class='sakuhinbako' style=\"background-image: url('${\(image_makase('flower/png', $seed+1))}')\">";
		print "<div class='hidari' style=\"background-image: url('${\(image_makase('flower/png', $seed))}')\">";
			print "<a class='modoru' href='${\(url_get_hazusi(\%url_get, 'id'))}'>${\(Kahifu::Template::dict('MODORU'))}</a>";
			print "<div class='heading'>$sakuhin_info->{$passthrough_id}{midasi}</div>";
			print "<div class='subheading'>$sakuhin_info->{$passthrough_id}{fukumidasi}</div>";
			print "<div class='sakka'>$sakuhin_info->{$passthrough_id}{sakka}</div>";
			print "<div class='bunsyou'>";
			my $kansou_query = "select * from kansou_long where sid = ?";
			my $kansou_syutoku = $dbh->prepare($kansou_query);
			$kansou_syutoku->execute($passthrough_id);
			my $kansou_info = $kansou_syutoku->fetchall_hashref('sid');
			print Kahifu::Infra::bunsyou($kansou_info->{$passthrough_id}{kansou}) if defined $kansou_info->{$passthrough_id}{kansou};
			print "</div>";
			my $kutikomi_query = "select * from kutikomi where sid = ? order by jiten desc";
			my $kutikomi_syutoku = $dbh->prepare($kutikomi_query);
			$kutikomi_syutoku->execute($passthrough_id);
			while(my $kutikomi_info = $kutikomi_syutoku->fetchrow_hashref){
				print "<div class='kutikomi type_$kutikomi_info->{syurui} lang_${Kahifu::Junbi::lang}${\( sub { return ' hankakusi' if defined $kutikomi_info->{kakusu} && $kutikomi_info->{kakusu}==1 }->() )}'>";
				print "<div class='header'><span class='syurui'>", Kahifu::Template::dict('KUTIKOMI_TYPE_'.$kutikomi_info->{syurui}), "</span>";
				print "<span class='title'>";
				if(Kahifu::Template::tenmei){
					print "<form action='sakunai.pl' method='post'><input type='hidden' name='reference' value='$passthrough_id'><input type='hidden' name='kutikomi_id' value='$kutikomi_info->{id}'><button type='button' class='kakejiku_hannyou text' data-kakejiku='kutikomi_hensyuu'>", Kahifu::Template::dict('KUTIKOMI_HENSYUU'), "</button>";
					print $kutikomi_info->{kakusu} != 1 ? "<input class='text' type='submit' name='kutikomi_ingen' value='${\(Kahifu::Template::dict('KUTIKOMI_HIHYOUJI'))}'>" : "<input class='text' type='submit' name='kutikomi_ingen' value='${\(Kahifu::Template::dict('KUTIKOMI_HYOUJI'))}'>";
					print "<button type='button' class='kakejiku_hannyou text' data-kakejiku='kutikomi_sakujyo'>", Kahifu::Template::dict('KUTIKOMI_SAKUJYO'), "</button></form>";
				}
				print date($kutikomi_info->{jiten}, 8), "</span></div>";
				print "<div class='naiyou'>", Kahifu::Infra::bunsyou($kutikomi_info->{text}), "</div>";
				print "<form method='post' id='sakunai_kansou_$kutikomi_info->{id}' action='sakunai.pl'><input type='hidden' name='kutikomi_id' value='$kutikomi_info->{id}'><input type='hidden' name='jiten' value='$kutikomi_info->{jiten}'><div data-kakejiku='kutikomi_hensyuu'><div class='syurui'><input type='radio' id='kutikomi_syurui1' name='syurui' value='1' ${\( sub { return 'checked=checked' if defined $kutikomi_info->{syurui} && $kutikomi_info->{syurui}==1 }->() )}><label for='kutikomi_syurui1'><span>${\(Kahifu::Template::dict('KUTIKOMI_TYPE_1'))}</span></label><input type='radio' id='kutikomi_syurui2' name='syurui' value='2' ${\( sub { return 'checked=checked' if defined $kutikomi_info->{syurui} && $kutikomi_info->{syurui}==2 }->() )}><label for='kutikomi_syurui2'><span>${\(Kahifu::Template::dict('KUTIKOMI_TYPE_2'))}</span></label><input type='radio' id='kutikomi_syurui3' name='syurui' value='3' ${\( sub { return 'checked=checked' if defined $kutikomi_info->{syurui} && $kutikomi_info->{syurui}==3 }->() )}><label for='kutikomi_syurui3'><span>${\(Kahifu::Template::dict('KUTIKOMI_TYPE_3'))}</span></label><input type='radio' id='kutikomi_syurui4' name='syurui' value='4' ${\( sub { return 'checked=checked' if defined $kutikomi_info->{syurui} && $kutikomi_info->{syurui}==4 }->() )}><label for='kutikomi_syurui4'><span>${\(Kahifu::Template::dict('KUTIKOMI_TYPE_4'))}</span></label><input type='radio' id='kutikomi_syurui5' name='syurui' value='5' ${\( sub { return 'checked=checked' if defined $kutikomi_info->{syurui} && $kutikomi_info->{syurui}==5 }->() )}><label for='kutikomi_syurui5'><span>${\(Kahifu::Template::dict('KUTIKOMI_TYPE_5'))}</span></label><input type='radio' id='kutikomi_syurui4' name='syurui' value='6' ${\( sub { return 'checked=checked' if defined $kutikomi_info->{syurui} && $kutikomi_info->{syurui}==6 }->() )}><label for='kutikomi_syurui6'><span>${\(Kahifu::Template::dict('KUTIKOMI_TYPE_6'))}</span></label></div><textarea name='kutikomi' form='sakunai_kansou_$kutikomi_info->{id}'>", $kutikomi_info->{text}, "</textarea><input name='kutikomi_hensyuu' type='submit' value='${\(Kahifu::Template::dict('SOUSIN'))}'></div><div data-kakejiku='kutikomi_sakujyo'>${\(Kahifu::Template::dict('SAKUJYO_TYUUI'))}</div></form>";
				print "</div>";
			}
			print "<div data-kakejiku='kansou_long' class='kakejiku'><span>${\(Kahifu::Template::dict('KANSOU_HENSYUU_DESC'))}<span class='sinsyuku'>＋</span></span></div>" if Kahifu::Template::tenmei;
			print "<form method='post' id='sakunai_kansou' action='sakunai.pl'><input type='hidden' name='reference' value='${passthrough_id}'><div data-kakejiku='kansou_long'><textarea name='text' form='sakunai_kansou'>", $kansou_info->{$passthrough_id}{kansou}//'', "</textarea><input name='kansou_sousin' type='submit' value='${\(Kahifu::Template::dict('SOUSIN'))}'></div></form>";
			print "<div data-kakejiku='kutikomi' class='kakejiku'><span>${\(Kahifu::Template::dict('KUTIKOMI_KAKEJIKU'))}<span class='sinsyuku'>＋</span></span></div>" if Kahifu::Template::tenmei;
			print "<form method='post' id='sakunai_kutikomi' action='sakunai.pl'><input type='hidden' name='reference' value='${passthrough_id}'><div data-kakejiku='kutikomi'><div class='syurui'><input type='radio' id='kutikomi_syurui1' name='syurui' value='1' checked='checked'><label for='kutikomi_syurui1'><span>${\(Kahifu::Template::dict('KUTIKOMI_TYPE_1'))}</span></label><input type='radio' id='kutikomi_syurui2' name='syurui' value='2'><label for='kutikomi_syurui2'><span>${\(Kahifu::Template::dict('KUTIKOMI_TYPE_2'))}</span></label><input type='radio' id='kutikomi_syurui3' name='syurui' value='3'><label for='kutikomi_syurui3'><span>${\(Kahifu::Template::dict('KUTIKOMI_TYPE_3'))}</span></label><input type='radio' id='kutikomi_syurui4' name='syurui' value='4'><label for='kutikomi_syurui4'><span>${\(Kahifu::Template::dict('KUTIKOMI_TYPE_4'))}</span></label><input type='radio' id='kutikomi_syurui5' name='syurui' value='5'><label for='kutikomi_syurui5'><span>${\(Kahifu::Template::dict('KUTIKOMI_TYPE_5'))}</span></label><input type='radio' id='kutikomi_syurui6' name='syurui' value='6'><label for='kutikomi_syurui6'><span>${\(Kahifu::Template::dict('KUTIKOMI_TYPE_6'))}</span></label></div><textarea name='kutikomi' form='sakunai_kutikomi'></textarea><input name='kutikomi_sousin' type='submit' value='${\(Kahifu::Template::dict('SOUSIN'))}'></div></form>";
			print "<div data-kakejiku='ten' class='kakejiku'><span>${\(Kahifu::Template::dict('TENSUU'))}<span class='sinsyuku'>${\(Kahifu::Template::dict('SINSYUKU_PLUS'))}</span></span></div>" if Kahifu::Template::tenmei;
			print "<form method='post' id='sakunai_tennsuu' action='tensuu.pl'><input type='hidden' name='reference' value='${passthrough_id}'><div data-kakejiku='ten'><input name='tensuu_kojin' placeholder='私式→", $sakuhin_info->{$passthrough_id}{point}//'', "' value='", $sakuhin_info->{$passthrough_id}{point}//'', "'><input name='tensuu_mal_pt' placeholder='ﾏｲｱﾆ→", $sakuhin_info->{$passthrough_id}{mal_pt}//'', "／10' value='", $sakuhin_info->{$passthrough_id}{mal_pt}//'', "'><input name='tensuu_al_pt' placeholder='ｱﾆﾘｽﾄ→", $sakuhin_info->{$passthrough_id}{al_pt}//'', "／100' value='", $sakuhin_info->{$passthrough_id}{al_pt}//'', "'><input name='tensuu_bl_pt' placeholder='ﾌﾞｸﾛｸﾞ→", $sakuhin_info->{$passthrough_id}{bl_pt}//'', "／10' value='", $sakuhin_info->{$passthrough_id}{bl_pt}//'', "'><input name='tensuu_sousin' type='submit' value='${\(Kahifu::Template::dict('SOUSIN'))}'></div></form>";
		print "</div>";
		print "<div class='migi'>";
			print "<div class='tensuu'>", ten_henkan($sakuhin_info->{$passthrough_id}{point}), "</div>" if defined $sakuhin_info->{$passthrough_id}{point};
			my $collection_query = "select * from collection where midasi_seisiki in ($colle_placeholders)";
			my $collection_syutoku = $dbh->prepare($collection_query);
			$collection_syutoku->execute(@sakuhin_colle);
			while(my $v = $collection_syutoku->fetchrow_hashref){
				my $colle_seed = $v->{jiten} + 2;
				print "<div style='background-color: hsl(${\(color_makase($colle_seed))}, 60%, 88%)' class='colle'>";
					print "<a href='${\(url_get_tuke(\%url_get, 'collection', $v->{id}))}'>";
					print $v->{midasi};
					print "</a>";
					print my $sakuhin_bikou = ${\( sub { return "<div class='$v->{tag}'>" . from_json($v->{bikou})->{param('id')} . "</div>" if ref(from_json($v->{bikou})) ne 'ARRAY' && defined from_json($v->{bikou})->{param('id')} }->() )} if defined $v->{bikou} && $v->{bikou} ne '';
				print "</div>";
			}
			print "<div class='kansyourirekisyo'>";
			print "<form action='sakunai.pl' method='post'>";
			# 鑑賞履歴（作品ページ内）
				my $rireki_query = "select * from rireki where sid = ?";
				my $rireki_syutoku = $dbh->prepare($rireki_query);
				$rireki_syutoku->execute($passthrough_id);
				print "<div class='midasi'><span>${\(Kahifu::Template::dict('KANSYOURIREKISYO'))}</span></div>";
				print "<div class='rireki'>";
				print "<div class='gyou touroku'>";
					print "<div class='jiten${\( sub { return ' mikakutei' if $sakuhin_info->{$passthrough_id}{mikakutei}==1 }->() )}'>", date($sakuhin_info->{$passthrough_id}{time}, $sakuhin_info->{$passthrough_id}{mikakutei}, 1), "</div>";
					print "<div class='jyou'>${\(Kahifu::Template::dict('TOUROKU_JYOU'))}</div>";
				print "</div>";
				print "<div class='gyou'>";
					print "<div class='jiten${\( sub { return ' mikakutei' if $sakuhin_info->{$passthrough_id}{mikakutei}==1 }->() )}'>", date($sakuhin_info->{$passthrough_id}{hajimari}, $sakuhin_info->{$passthrough_id}{mikakutei}, 1), "</div>";
					print "<div class='jyou'>${\(Kahifu::Template::dict('HAJIMARI_JYOU'))}</div>";
				print "</div>";
				while(my $v = $rireki_syutoku->fetchrow_hashref){
					print "<div class='gyou' data-rireki='", $v->{id}, "'>";
						print "<div class='jiten${\( sub { return ' mikakutei' if $v->{mkt}==1 }->() )}'>", date($v->{jiten}, $v->{mkt}, 1), "</div>";
						print "<div class='jyou'>", jyoukyou_settei($v->{jyoukyou}, $sakuhin_info->{$passthrough_id}{hajimari}, $v->{owari}, 609, $sakuhin_info->{$passthrough_id}{eternal}), "</div>";
						print "<div class='sintyoku'>", $v->{part}, '／', $v->{whole}, $v->{josuu}, "</div>";
						print "<div class='memo'>", $v->{text}, "</div>" if defined $v->{text};
					print "</div>";
					print "<div class='gyou hensyuu' data-rireki='", $v->{id}, "'>";
						print "<input type='hidden' name='reference' value='", $v->{id}, "'>";
						print "<div class='jiten_hi'>";
							print "<div class='jiten_y'><input type='text' name='jiten_y'  placeholder='", date_split($v->{jiten}, 0), "' value='", date_split($v->{jiten}, 0), "'>${\(Kahifu::Template::dict('TOSI'))}</div>";
							print "<div class='jiten_m'><input type='text' name='jiten_m'  placeholder='", date_split($v->{jiten}, 1), "' value='", date_split($v->{jiten}, 1), "'>${\(Kahifu::Template::dict('TUKI'))}</div>";
							print "<div class='jiten_d'><input type='text' name='jiten_d'  placeholder='", date_split($v->{jiten}, 2), "' value='", date_split($v->{jiten}, 2), "'>${\(Kahifu::Template::dict('HI'))}</div>";
						print "</div>";
						print "<div class='jiten_jikan'>";
							print "<div class='jiten_h'><input type='text' name='jiten_h' placeholder='", date_split($v->{jiten}, 3), "' value='", date_split($v->{jiten}, 3), "'>${\(Kahifu::Template::dict('JI'))}</div>";
							print "<div class='jiten_i'><input type='text' name='jiten_i'  placeholder='${\(sprintf(\"%02s\", date_split($v->{jiten}, 4)))}' value='${\(sprintf(\"%02s\", date_split($v->{jiten}, 4)))}'>${\(Kahifu::Template::dict('FUN'))}</div>";
							print "<div class='jiten_s'><input type='text' name='jiten_s'  placeholder='${\(sprintf(\"%02s\", date_split($v->{jiten}, 10)))}' value='${\(sprintf(\"%02s\", date_split($v->{jiten}, 10)))}'>${\(Kahifu::Template::dict('BYOU'))}</div>";
							print "<div class='jiten_unix'><input type='text'  name='jiten_unix' placeholder='", $v->{jiten}, "'></div>";
						print "</div>";
						print "<div class='sintyoku'>";
							my $jyoukyou_list = $dbh->prepare("select jyoukyou from `jyoukyou` where id not in (1, 8, 9, 10, 11, 12)");
							$jyoukyou_list->execute();
							print "<select name='jyoukyou'>";
							while(my $w = $jyoukyou_list->fetchrow_hashref){
								print "<option value='$w->{jyoukyou}' ${\( sub { return ' selected=selected' if $w->{jyoukyou} eq $v->{jyoukyou} }->() )}>$w->{jyoukyou}</option>";
							}
							print "</select>";
							print "<div class='part'><input type='text'  name='part' placeholder='", $v->{part}, "' value='", $v->{part}, "'></div>／";
							print "<div class='whole'><input type='text' name='whole'  placeholder='", $v->{whole}, "' value='", $v->{whole}, "'></div>";
							print "<div class='josuu'><input type='text' name='josuu'  placeholder='", $v->{josuu}, "' value='", $v->{josuu}, "'></div>";
							print "<div class='mikakutei'><select name='mikakutei' ><option value='1'${\( sub { return ' selected=selected' if $v->{mkt}==1 }->() )}>${\(Kahifu::Template::dict('MIKAKUTEI_JYOU'))}</option><option value='0'${\( sub { return ' selected=selected' if $v->{mkt}==0 }->() )}>${\(Kahifu::Template::dict('KAKUTEI_JYOU'))}</option></select></div>";
						print "</div>";
						print "<div class='text'>";
							print "<input type='text'  name='text' placeholder='", $v->{text}, "' value='", $v->{text}, "'>";
						print "</div>";
					print "</div>";
				}
				print "</div>";
				print "<div class='rireki_sousin'><input name='rireki_sousin' type='submit' value='${\(Kahifu::Template::dict('SOUSIN'))}'></div>";
			print "</form>";
			print "</div>";
		print "</div>";
	print "</div>";
	
	print '<script>
	$(\'div.sakuhinbako > div.migi > div.kansyourirekisyo > form > div.rireki > div.gyou > div.jiten\').on(\'click\', function() {
		$(\'div.sakuhinbako > div.migi > div.kansyourirekisyo > form > div.rireki > div.gyou.hensyuu[data-rireki=\' + $(this).parent().attr(\'data-rireki\') + \']\').slideToggle();
		$(\'div.rireki_sousin\').show();
	});
  	</script>';
	print Kahifu::Template::html_noti();
	exit;
}

# 
#　カタログ一覧
#　カタログ、履歴、蒐集などなど
#
#
my ($kensaku, $kensaku_sitazi, $gyaku_kensaku_sitazi, $hantyuu_sibori_sitazi, $jyoukyou_sibori_sitazi, $narabikae_sitazi, $jun_sitazi, @sitazi_bind, @sitazi_bind_2);
$gyaku_kensaku_sitazi = "(`yotei` <> 1 or `yotei` is null) and ";
if (defined param('kensaku') && param('kensaku')){
	$kensaku = "${\(decode_utf8(param('kensaku')))}";
	$kensaku_sitazi = "and (`midasi` like ? or `fukumidasi` like ? or `sakka` like ?)";
	$gyaku_kensaku_sitazi = "";
	push @sitazi_bind, ("%${kensaku}%", "%${kensaku}%", "%${kensaku}%");
	push @sitazi_bind_2, ("%${kensaku}%", "%${kensaku}%", "%${kensaku}%") if $page == 1;	
} else { $kensaku_sitazi = ""; }
if (defined $siborikomi_hantyuu && $siborikomi_hantyuu && $siborikomi_hantyuu ne '50'){ 
	$hantyuu_sibori_sitazi = "and (`hantyuu` in (?))";
	push @sitazi_bind, ($siborikomi_hantyuu);
	push @sitazi_bind_2, ($siborikomi_hantyuu) if $page == 1;
} else { $hantyuu_sibori_sitazi = ""; }
if (defined $siborikomi_jyoukyou && $siborikomi_jyoukyou && $siborikomi_jyoukyou ne '1'){ 
	$jyoukyou_sibori_sitazi = "and (`jyoukyou` in (?))";
	push @sitazi_bind, ("${\(Kahifu::Template::dict('HYOUKA_JYOUKYOU_' . ${\($siborikomi_jyoukyou)}))}");
	push @sitazi_bind_2, ("${\(Kahifu::Template::dict('HYOUKA_JYOUKYOU_' . ${\($siborikomi_jyoukyou)}))}") if $page == 1;
} else { $jyoukyou_sibori_sitazi = ""; }
my @narabi_henkan = ('`owari`', '`hajimari`', '`time`', '`point`');
my @jun_henkan = ('desc', 'asc');
my $narabi_tuuka = (defined $narabi_henkan[$narabi-1]) ? $narabi_henkan[$narabi-1] : $narabi_henkan[0];
my $jun_tuuka = (defined $jun_henkan[$jun]) ? $jun_henkan[$jun] : $jun_henkan[0];
my $junni_tuuka = ($jun == 0) ? 'asc' : 'desc';

# paginateの準備をする
my @josuu_tati = $dbh->selectall_array("select `josuu`, `ja` from `josuu`");
my @sizi_tati = $dbh->selectall_array("select `sizi` from `josuu_sizi`");
my ($current_turu, @r, @current_list, $row_count, $page_saigo, $meirei_presitami, $meirei_sitami, $count_sitami, $page_subete);
my ($kansyou_current_rows, $kansyou_all_rows);
my (@hantyuu_type, @hantyuu_data, @hantyuu_class, %jyoukyou_type, %jyoukyou_class, @jyoukyou_name);
my (@meirei, @daimei);
#　paginate=3の
my (@week_border_original, $week_limit_lower, $week_limit_upper, $koyomi_week_count, $dst_musi_week_limit_lower);
my (@rireki_sakuhin, @rireki_count);
my ($hantyuu_syutoku, %koyomi_hantyuu_winner);
my ($rirekiran);
my $listen_index = 0;
my (@listen_time, @listen_info_artist, @listen_info_album, @listen_info_track, %listen_session_hash_artist, %listen_session_hash_album, %listen_session_hash_track);
if($paginate == 1){
	#　最初のページの行数を数える（鑑賞中＋鑑賞ずみ）
	$meirei_presitami = $dbh->prepare("select `id` from `sakuhin` where ${gyaku_kensaku_sitazi} (`jyoukyou` = '中' or `jyoukyou` = '再' or `current` = 1) and (`current` is null or `current` != 2) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi}");
	$meirei_presitami->execute();
	$kansyou_current_rows = $meirei_presitami->rows();
	# $row_count = ($page == 1) ? $kansyou_current_rows + 20 : 20;
	$row_count = 20;
	#　idたちを集める
	# 旧meirei: select `id` from `sakuhin` where ((!(`jyoukyou` = '中' or `jyoukyou` = '再') and (`current` is null or `current` != 1)) or ((`jyoukyou` = '中' or `jyoukyou` = '再') and `current` = 2))||(((`jyoukyou` = '中' or `jyoukyou` = '再' or (`current` = 1)) and (`current` is null or `current` != 2))) order by `owari` desc limit ${row_count} offset ?
	$meirei_sitami = ($page == 1) ? $dbh->prepare("select * from 
		(select `id`, `owari`, `hajimari`, `time`, `point`, `junni` from `sakuhin` where ${gyaku_kensaku_sitazi} (((`jyoukyou` = '中' or `jyoukyou` = '再' or (`current` = 1)) and (`current` is null or `current` != 2))) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi}) a union select * from (select `id`, `owari`, `hajimari`, `time`, `point`, `junni` from `sakuhin` where ${gyaku_kensaku_sitazi} (!(`jyoukyou` = '中' or `jyoukyou` = '再') and ((`current` is null or `current` != 1)) or ((`jyoukyou` = '中' or `jyoukyou` = '再') and `current` = 2)) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} order by ${narabi_tuuka} ${jun_tuuka}, `junni` ${junni_tuuka} limit ${row_count} offset ? ) b order by ${narabi_tuuka} ${jun_tuuka}, `junni` ${junni_tuuka}") : $dbh->prepare("select `id`, `midasi` from `sakuhin` where ${gyaku_kensaku_sitazi} ((!(`jyoukyou` = '中' or `jyoukyou` = '再') and (`current` is null or `current` != 1)) || ((`jyoukyou` = '中' or `jyoukyou` = '再') and `current` = 2)) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} order by ${narabi_tuuka} ${jun_tuuka}, `junni` ${junni_tuuka} limit ${row_count} offset ?");
		# 修正→`id`だけでmeireiと不一致になります。一体どうして？？？
	$page != 1 ? $meirei_sitami->execute(@sitazi_bind, $page_offset) : 	$meirei_sitami->execute(@sitazi_bind, @sitazi_bind_2, $page_offset);
	while(my $v = $meirei_sitami->fetchrow_hashref){
		push @current_list, $v->{id};	
	}
	$current_turu = join(',', @current_list);
	$current_turu = 0 if $current_turu eq '';
	@r = $dbh->selectall_array("select * from `rireki` where `sid` in ($current_turu)");
	#　クエリーに伴って全ての行数を数える
	$count_sitami = $dbh->prepare("select `id` from `sakuhin` where ${gyaku_kensaku_sitazi} (((!(`jyoukyou` = '中' or `jyoukyou` = '再') and (`current` is null or `current` != 1)) or ((`jyoukyou` = '中' or `jyoukyou` = '再') and `current` = 2))||(((`jyoukyou` = '中' or `jyoukyou` = '再' or (`current` = 1)) and (`current` is null or `current` != 2)))) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi}");
	$count_sitami->execute(@sitazi_bind);
	$kansyou_all_rows = $count_sitami->rows();
	$page_subete = ceil((($kansyou_all_rows - $kansyou_current_rows - 20) / 20) + 1);
	
	@meirei = ("select * from `sakuhin` where ${gyaku_kensaku_sitazi} ((`jyoukyou` = '中' or `jyoukyou` = '再' or (`current` = 1)) ${kensaku_sitazi} and (`current` is null or `current` != 2)) ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} order by `owari` desc", "select * from `sakuhin` where ${gyaku_kensaku_sitazi} ((!(`jyoukyou` = '中' or `jyoukyou` = '再') and (`current` is null or `current` != 1)) || ((`jyoukyou` = '中' or `jyoukyou` = '再') and `current` = 2)) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} order by ${narabi_tuuka} ${jun_tuuka}, `junni` ${junni_tuuka} limit 20 offset ?");
	@daimei = ("${\(Kahifu::Template::dict('TITLE_KANSYOUTYUU'))}", "${\(Kahifu::Template::dict('TITLE_KANSYOUZUMI'))}");
} elsif($paginate == 2){
	# コレクション検索機能など

} elsif ($paginate == 3){
	# 暦を作るには…
	@week_border_original = week_border(${\(week($imagenzai))[0]}, ${\(week($imagenzai))[1]}, $sanjyuujikan_seido);
	$week_limit_lower = $week_border_original[0] - (($week - 0) * 604800); #lower = 古いの方
	$week_limit_upper = $week_border_original[0] - (($week - 1) * 604800); #upper = 新しいの方
	$dst_musi_week_limit_lower = ($week_border_original[0] - (($week - 0) * 604800)) + 3600;
	$koyomi_week_count = week_count(${\(week($dst_musi_week_limit_lower))[0]}) == 1 ? 52 : 53; # yr from yr,wk of weeklimlower to count
	#　part != 前のpart & jyou!=終（再開の場合を除く）	→週別（yearweek）で範疇の頻度を
	$hantyuu_syutoku = "select YEARWEEK(FROM_UNIXTIME(reki.`jiten` - ${sanjyuujikansei_offset}), 1) as `week`, `jiten`, `hantyuu`, count(*) as `count` from (SELECT (\@partpre = part AND \@sidpre=sid AND `jyoukyou` not in ('終','葉','中')) AS unchanged_status, rireki.*, \@partpre := part, \@sidpre := sid from rireki, (select \@partpre:=NULL, \@sidpre:=NULL) AS x order by sid, jiten) as reki left join sakuhin saku on reki.sid = saku.id where substring(YEARWEEK(FROM_UNIXTIME(reki.`jiten` - ${sanjyuujikansei_offset}), 1), 1, 4) = ? ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} and not unchanged_status group by `hantyuu`, `week` union all select YEARWEEK(FROM_UNIXTIME(`date` - ${sanjyuujikansei_offset}), 1) as `week`, `date` as `jiten`, 900 as `hantyuu`, floor((count(*) * 4.427)/60)/1.5 as `count` from (select `name` as `midasi`, `album` as `fukumidasi`, `artist` as `sakka`, 900 as `hantyuu`, '終' as `jyoukyou`, listen.* from `listen`) as listen where 1=1 ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} group by `week` order by jiten desc";
	#music_syutoku = "select YEARWEEK(FROM_UNIXTIME(`date`), 1) as `week`, 900 as `hantyuu`, floor((count(*) * 4.427)/60) as `count` from `listen` group by `week`"
	my $koyomi_hantyuu = $dbh->prepare($hantyuu_syutoku);
	$koyomi_hantyuu->execute(${\(week($dst_musi_week_limit_lower))[0]}, @sitazi_bind, @sitazi_bind);
	sub collapse_hantyuu {
		my $hantyuu = shift//6;
		return 7 if $hantyuu == 16 || $hantyuu == 24;
		return 68 if $hantyuu == 67;
		return 6 if $hantyuu == 25 || $hantyuu == 26 || $hantyuu == 18;
		return 14 if $hantyuu == 17;
		return 12 if $hantyuu == 15 || $hantyuu == 102;
		return $hantyuu;
	}
	my ($hantyuu_atumari, $last_week_hantyuu, $hantyuu_syori);
	while(my $v = $koyomi_hantyuu->fetchrow_hashref){
		undef %{$hantyuu_atumari} if $v->{week} != $last_week_hantyuu;
		$last_week_hantyuu = $v->{week};
		$hantyuu_syori = collapse_hantyuu($v->{hantyuu});
		$hantyuu_atumari->{"$hantyuu_syori"} += $v->{count};
		my @hantyuu_inner_array = ($v->{week}, $hantyuu_syori, $hantyuu_atumari->{$hantyuu_syori});		
		$koyomi_hantyuu_winner{$v->{week}} = \@hantyuu_inner_array if(defined $koyomi_hantyuu_winner{$v->{week}} && $v->{week} eq $koyomi_hantyuu_winner{$v->{week}}[0] && $koyomi_hantyuu_winner{$v->{week}}[2] < $hantyuu_atumari->{$hantyuu_syori} || not defined $koyomi_hantyuu_winner{$v->{week}});
	}

	#audioscrobbler/listen組み込み
	my $listen_row_iter;
	# 	my $listen_query = "select * from (select *,  `name` as `midasi`, `album` as `fukumidasi`, `artist` as `sakka`, 900 as `hantyuu`, '終' as `jyoukyou`, lead(`date`) over (order by `date`) - `date` as `lag` from `listen`) as `listen` where `date` < ? && `date` >= ? ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi}"; # 処理時間が長すぎたため、`lag`を保存するようにしました。400ms->20msになりましたが、更新時（現在kousin.plの264-266行を参照）に800msくらいのupdateクエリーを行う必要があります。一得一失うんぬん。
	my $listen_query = "select * from (select *,  `name` as `midasi`, `album` as `fukumidasi`, `artist` as `sakka`, 900 as `hantyuu`, '終' as `jyoukyou` from `listen`) as `listen` where `date` < ? && `date` >= ? ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi}";
	my $listen_syutoku = $dbh->prepare($listen_query);
	$listen_syutoku->execute($week_limit_upper, $week_limit_lower, @sitazi_bind);
	my $listen_row_count = $listen_syutoku->rows;
	while(my $v = $listen_syutoku->fetchrow_hashref){
		$listen_row_iter++;
		$listen_session_hash_artist{$v->{artist}}++;
		$listen_session_hash_album{$v->{album}}++;
		$listen_session_hash_track{$v->{name}}++;
		if((defined $v->{lag} && $v->{lag} > 1800) || $listen_row_iter == $listen_row_count){
			push @listen_time, $v->{date};
			push @listen_info_artist, to_json(\%listen_session_hash_artist);
			push @listen_info_album, to_json(\%listen_session_hash_album);
			push @listen_info_track, to_json(\%listen_session_hash_track);
			undef %listen_session_hash_artist;
			undef %listen_session_hash_album;
			undef %listen_session_hash_track;
			$listen_index++;
		}
	}

	@meirei = ("select reki.*, saku.midasi, saku.betumei, saku.hantyuu, saku.kakusu from (select (\@partpre = part and \@sidpre=sid and `jyoukyou` not in ('終','葉','中')) as unchanged_status, rireki.*, \@partpre := part, \@sidpre := sid from rireki, (select \@partpre:=NULL, \@sidpre:=NULL) as x order by sid, jiten) as reki left join sakuhin saku on reki.sid = saku.id where not unchanged_status and reki.jiten >= ? and reki.jiten <= ? ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} union all select 0 as unchanged_status, 0 as id, sid, jiten, 0 as part, 0 as whole, syurui as jyoukyou, 0 as josuu, 0 as mkt, `text`, 0 `\@partpre := part`, 0 as `\@sidpre=sid`, saku.midasi as midasi, saku.betumei as betumei, 700 as hantyuu, kutikomi.kakusu from kutikomi left join sakuhin saku on kutikomi.sid = saku.id where jiten >= ? and jiten <= ? ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} order by jiten desc;", "select reki.jiten, saku.hantyuu from (select (\@partpre = part and \@sidpre=sid and `jyoukyou` not in ('終','葉','中')) as unchanged_status, rireki.*, \@partpre := part, \@sidpre := sid from rireki, (select \@partpre:=NULL, \@sidpre:=NULL) as x order by sid, jiten) as reki left join sakuhin saku on reki.sid = saku.id where not unchanged_status ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} and reki.jiten >= ? and reki.jiten <= ? order by jiten desc;");
}

if(!(Kahifu::Template::tenmei() || $ninsyou)){
	print "<form action='aikotoba.pl' method='post'>";
	print "<div class='aikotoba'>";
		print "<span>${\(Kahifu::Template::dict('AIKOTOBA_SETUMEI'))}</span>";
		print "<input type='text' name='pass'>";
		print "<input type='submit' name='aikotoba_submit' value='submit'>";
	print "</div>";
	print "</form>";
}

print "<div class='commander'>";
	print "<div class='hidari'>";
		print "<div class='navi'>";
			if($paginate == 1){
				print "<a href='${\(url_get_tuke(\%url_get, 'page', ${\($page-1)}))}'>←</a>" if $page != 1;
				print "<span>";
				print "page ";
				print my $page = (defined param('page')) ? param('page') : 1;
				print "${\(Kahifu::Template::dict('SLASH'))}";
				print $page_subete;
				print "</span>";
				print "<a class='migi' href='${\(url_get_tuke(\%url_get, 'page', ${\($page+1)}))}'>→</a>" if $page + 1 <= $page_subete;
			} elsif ($paginate == 2){
				print "<a href='${\(url_get_hazusi(\%url_get, 'collection'))}'>${\(Kahifu::Template::dict('MODORUZEYO'))}</a>" if defined param('collection');
				print "<span>${\(Kahifu::Template::dict('COLLECTION_HEADING'))}</span>" if not defined param('collection');
			} elsif ($paginate == 3){
				print "<a href='${\(url_get_tuke(\%url_get, 'week', ${\($week-1)}))}'>←</a>" if $week != 0;
				print "<span>${\(sub { return $week>0 ? \"第${week}週\" : \"${\(Kahifu::Template::dict('WEEK_TITLE_FIRST'))}\" }->())}${\(Kahifu::Template::dict('EIGOYOU_KUUHAKU'))}${\(Kahifu::Template::dict('NYORO'))}${\(week($dst_musi_week_limit_lower))[0]}${\(Kahifu::Template::dict('SUFFIX_TOSI'))}${\(Kahifu::Template::dict('EIGOYOU_KUUHAKU'))}${\(map { s/###/${\(week($dst_musi_week_limit_lower))[1]}/; $_ } do { ${\(Kahifu::Template::dict('WEEK_TITLE'))} }) }${\(Kahifu::Template::dict('NYORO'))}</span>";
				print "<a class='migi' href='${\(url_get_tuke(\%url_get, 'week', ${\($week+1)}))}'>→</a>" if $week + 1;
			}
		print "</div>";
		if($paginate != 3){
			print "<div class='hanrei'>";
				print "<span>${\(Kahifu::Template::dict('HYOUKA_STYLE'))}</span>";
				print "<div id='settei_sakura' data-style='stylesheet/sakura.css' class='theme sakura'>${\(Kahifu::Template::dict('HYOUKA_STYLE_1'))}</div>";
				print "<div id='settei_gokusaisiki' data-style='stylesheet/gokusaisiki.css' class='theme gokusaisiki'>${\(Kahifu::Template::dict('HYOUKA_STYLE_2'))}</div>";
				print "<div id='settei_flora' data-style='stylesheet/flora.css' class='theme flora'>${\(Kahifu::Template::dict('HYOUKA_STYLE_3'))}</div>";
			print "</div>";

			print "<div class='hanrei'>";
				print "<span>${\(Kahifu::Template::dict('HYOUKA_GENGO_SETTEI'))}</span>";
				print "<div id='settei_original' data-lang='1' class='lang original'>${\(Kahifu::Template::dict('HYOUKA_GENGO_SETTEI_1'))}</div>";
				print "<div id='settei_learned' data-lang='2' class='lang learned'>${\(Kahifu::Template::dict('HYOUKA_GENGO_SETTEI_2'))}</div>";
				print "<div id='settei_browser' data-lang='3' class='lang browser'>${\(Kahifu::Template::dict('HYOUKA_GENGO_SETTEI_3'))}</div>";
			print "</div>";
			
			print "<div class='hanrei button'>";
				print "<span>${\(Kahifu::Template::dict('HYOUKA_HANTYUU'))}</span>";
				my $hantyuu_list = $dbh->prepare("select * from `hantyuu`");
				$hantyuu_list->execute();
				while(my $v = $hantyuu_list->fetchrow_hashref){
					print "<div data-nokori='$v->{hantyuu}' class='hantyuu_$v->{class}'>${\(Kahifu::Template::dict('HYOUKA_HANTYUU_' . $v->{orig_id}))}</div>";
					push @hantyuu_type, $v->{orig_id};
					push @hantyuu_data, $v->{hantyuu};
					push @hantyuu_class, $v->{class};
				}
			print "</div>";
			print "<div class='hanrei jyoukyou_itirann'>";
				print "<span>${\(Kahifu::Template::dict('HYOUKA_JYOUKYOU'))}</span>";
				my $jyoukyou_list = $dbh->prepare("select * from `jyoukyou`");
				$jyoukyou_list->execute();
				while(my $v = $jyoukyou_list->fetchrow_hashref){
					print "<div title='${\(Kahifu::Template::dict('HYOUKA_JYOU_KAISETU_' . $v->{id}))}' class='jyoukyou${\( sub { return ' all' if $v->{id}==1})->()}' data-name='$v->{jyoukyou}'><span class='jyoukyou_type_$v->{id} $v->{class}'>${\(Kahifu::Template::dict('HYOUKA_JYOUKYOU_' . $v->{id}))}</span></div>" if $v->{jyoukyou} ne "葉" && $v->{jyoukyou} ne "飛";
					print "<style>.jyoukyou_type_$v->{id} { color: hsla($v->{hsl}, 1); }</style>";
					$jyoukyou_type{$v->{jyoukyou}} = $v->{id};
					$jyoukyou_class{$v->{jyoukyou}} = $v->{class};
					push @jyoukyou_name, $v->{jyoukyou};
				}
			print "</div>";
		} elsif ($paginate == 3) {
			my $hantyuu_list = $dbh->prepare("select * from `hantyuu`");
			$hantyuu_list->execute();
			while(my $v = $hantyuu_list->fetchrow_hashref){
				push @hantyuu_type, $v->{orig_id};
				push @hantyuu_data, $v->{hantyuu};
				push @hantyuu_class, $v->{class};
			}
			my $jyoukyou_list = $dbh->prepare("select * from `jyoukyou`");
			$jyoukyou_list->execute();
			while(my $v = $jyoukyou_list->fetchrow_hashref){
				print "<style>.jyoukyou_type_$v->{id} { color: hsla($v->{hsl}, 1); }</style>";
				$jyoukyou_type{$v->{jyoukyou}} = $v->{id};
				$jyoukyou_class{$v->{jyoukyou}} = $v->{class};
				push @jyoukyou_name, $v->{jyoukyou};
			}
			print "<div class='koyomi'>";
				for(my $i = $koyomi_week_count; $i > 0; $i--){
					print "<div class='sihanki'>" if ($i == 53 || ($i == 52 && $koyomi_week_count == 52)) || ($i % 13 == 0 && $i < 52);
					my $week_abs = week_delta($imagenzai, ${\(week_border(${\(week($dst_musi_week_limit_lower))[0]}, $i))[0]});
					print "<div class='syuu hannyou type_${\(sub { return ${koyomi_hantyuu_winner{${\(week($dst_musi_week_limit_lower))[0]}.${\(sprintf(\"%02s\", $i))}}[1]} if defined ${koyomi_hantyuu_winner{${\(week($dst_musi_week_limit_lower))[0]}.${\(sprintf(\"%02s\", $i))}}[1]}}->())} ${\(sub { return ' highlight_syuu' if $week_abs==$week && ${\(week_border(${\(week($dst_musi_week_limit_lower))[0]}, $i))[0]} < $imagenzai }->())}'>";
						print "<span>";
						print ${\(week_border(${\(week($dst_musi_week_limit_lower))[0]}, $i))[0]} < $imagenzai && $week != $week_abs ? "<a href='${\(url_get_tuke(\%url_get, 'week', $week_abs))}'>$i</a>" : "<span>$i</span>";
						print "</span>";
					print "</div>";
					print "</div>" if ($i % 13 == 1 && $i != 53);
				}
			print "</div>";
			print "<div class='syuu_mekuri'>";
				print "<div class='tosituki'>";
					print "<div class='year'>";
					print ${\(date_split($week_limit_lower, 0))} eq ${\(date_split($week_limit_upper, 0))} ? "<span class='hito'>${\(date_split($dst_musi_week_limit_lower, 0))}</span>" : "<span class='futa'>${\(date_split($week_limit_lower, 0))}<br>${\(date_split($week_limit_upper, 0, 1))}</span>";
					print "</div>";
					print "<div class='month'>";
					print ${\(date_split($week_limit_lower, 1))} eq ${\(date_split($week_limit_upper, 1))} ? "<span class='hito'>${\(date_split($dst_musi_week_limit_lower, 1))}</span>" : "<span class='futa'><sup>${\(date_split($week_limit_lower, 1))}</sup>⁄<sub>${\(date_split($week_limit_upper, 1))}</sub></span>";
					print "</div>";
				print "</div>";
				my $day = 0;
				my $rireki_nijiran = $dbh->prepare($meirei[1]);
				$rireki_nijiran->execute($week_limit_lower, $week_limit_upper, @sitazi_bind);
				my $rireki_nijiran_result = $rireki_nijiran->fetchall_arrayref();
				#for(my $i=0; $i<scalar(@$rireki_nijiran_result); $i++){$rireki_nijiran_result->[$i] = $rireki_nijiran_result->[$i][0]}
				for(my $i = 0; $i < 7; $i++){
					#　既に実行されていますからもう一度実行できないということです。
					#　実装する場合にはfetchallはたまたselectallで事前に使いなさい。それでforでループして。
					my $day_count = 0;
					my %mekuri_color;
					foreach my $j (@$rireki_nijiran_result){
						$day_count++ if $j->[0] > $week_limit_lower+$day && $j->[0] < $week_limit_lower+$day+86400;
						$mekuri_color{$j->[1]}++ if $j->[0] > $week_limit_lower+$day && $j->[0] < $week_limit_lower+$day+86400;
					}
					print %mekuri_color ? "<div class='youbi hannyou type_${\(hash_max_key(%mekuri_color))}'>" : "<div class='youbi'>";
						print "<div class='youbi day_${\(date_split($dst_musi_week_limit_lower+$day, 6))}'>${\(date_split($dst_musi_week_limit_lower+$day, 5))}</div>";
						print "<div class='hiduke'>${\(date_split($dst_musi_week_limit_lower+$day, 2))}</div>";
						print "<div class='kensuu'><span>${day_count}${\(Kahifu::Template::dict('JOSUU_KEN'))}</span></div>";
					print "</div>";
					$day = $day + 86400;
				}
			print "</div>";
		}
	print "</div>";
	
	print "<div class='migi'>";
		print "<div class='maegaki'>";
			print "<p>${\(Kahifu::Template::dict('HYOUKA_MAEGAKI'))}</p>";
		print "</div>";
		print "<div class='kinkyou'>";
			print "<p><span>${\(Kahifu::Template::dict('KINKYOU_HEADING'))}</span>さあ、どうでしょうね。</p>";
		print "</div>";
		print "<div class='control'>";
			print "<form method='post'>";
			print "<input type='submit' name='paginate' value='${\(Kahifu::Template::dict('PAGINATE_1'))}'";
				print " disabled=disabled" if $paginate == 1;
			print ">";
			print "<input type='submit' name='favorite' value='${\(Kahifu::Template::dict('PAGINATE_2'))}'";
				print " disabled=disabled" if $paginate == 2;
			print ">";
			print "<input type='submit' name='rireki' value='${\(Kahifu::Template::dict('PAGINATE_3'))}'";
				print " disabled=disabled" if $paginate == 3;
			print ">";
			print "</form>";
		print "</div>";
		print "<div class='narabikae'>";
			print "<form method='post'>";
			print "<div class='hidari'>";
				print "<div class='siborikomibako'>";
					print "<select name='page_siborikomi_hantyuu' class='hantyuu_all'>";
					for my $i (0 .. scalar @hantyuu_type - 1) {
						print "<option class='hantyuu_$hantyuu_class[$i]' value='$hantyuu_data[$i]' ${\( sub { return 'selected=selected' if ${siborikomi_hantyuu} eq $hantyuu_data[$i] }->() )}>${\(Kahifu::Template::dict('HYOUKA_HANTYUU_' . $hantyuu_type[$i]))}</option>";
					}
					print "</select>";
					print "<select class='jyoukyou_type_1' name='page_siborikomi_jyoukyou'>";
					for my $i (0 .. scalar @jyoukyou_name - 1) {
						print "<option class='jyoukyou_type_${\($i+1)} $jyoukyou_class{$jyoukyou_name[$i]}' value='${\($i+1)}' ${\( sub { return 'selected=selected' if defined ${siborikomi_jyoukyou} && ${siborikomi_jyoukyou}==${\($i+1)} }->() )}>${\(Kahifu::Template::dict('HYOUKA_JYOUKYOU_' . ${\($i+1)}))}</option>";
					}
					print "</select>";
					print "<select name='narabi'>";
						print "<option value='1'${\( sub { return 'selected=selected' if $narabi==1 }->() )}>${\(Kahifu::Template::dict('NARABIKAE_1'))}</option>";
						print "<option value='2'${\( sub { return 'selected=selected' if $narabi==2 }->() )}>${\(Kahifu::Template::dict('NARABIKAE_2'))}</option>";
						print "<option value='3'${\( sub { return 'selected=selected' if $narabi==3 }->() )}>${\(Kahifu::Template::dict('NARABIKAE_3'))}</option>";
						print "<option value='4'${\( sub { return 'selected=selected' if $narabi==4 }->() )}>${\(Kahifu::Template::dict('NARABIKAE_4'))}</option>";
					print "</select>";
					print "<select name='jun'>";
						print "<option value='0'${\( sub { return 'selected=selected' if $jun==0 }->() )}>↓</option>"; #降順
						print "<option value='1'${\( sub { return 'selected=selected' if $jun==1 }->() )}>↑</option>"; #昇順				
					print "</select>";
				print "</div>";
				print "<div class='kensakubako'>";
					print "<input type='text' name='kensaku' placeholder='${\(Kahifu::Template::dict('KENSAKU_PLACEHOLDER'))}' value='${\( sub { return $kensaku if defined ${kensaku} }->() )}'>";
				print "</div>";
			print "</div>";
			print "<div class='botanbako'>";
				print "<input type='submit' value='${\(Kahifu::Template::dict('KETTEI'))}' name='narabikae_kettei'>";
				print "<input type='submit' value='${\(Kahifu::Template::dict('KAIJYO'))}' name='kaijyo'>" if (param('kensaku'));
			print "</div>";
			print "</form>";
		print "</div>";
	print "</div>";
print "</div>";

#　初期レイアウト（頁化欄）
#　PAGINATE=1
#
if($paginate == 1){
	# 管理人　→記録ツール
	if(Kahifu::Template::tenmei()){
		print "<div data-kakejiku='kiroku' class='kakejiku kiroku'>";
			print "<span>${\(Kahifu::Template::dict('KIROKU_SINSYUKU'))}<span class='sinsyuku'>${\(Kahifu::Template::dict('SINSYUKU_PLUS'))}</span></span>";
		print "</div>";
		print "<div data-kakejiku='kiroku' class='form kiroku'>";
			print "<form method='post' action='kiroku.pl'>";
			print "<div class='cream'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_TITLE'))}</span><input type='text' name='midasi' placeholder='${\(Kahifu::Template::dict('KIROKU_TITLE_PLACEHOLDER'))}'></div>";
			print "<div class='cream'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_SUBTITLE'))}</span><input type='text' name='fukumidasi' placeholder='${\(Kahifu::Template::dict('KIROKU_SUBTITLE_PLACEHOLDER'))}'></div>";
			print "<div class='sky'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_SAKKA'))}</span><input type='text' name='sakka' placeholder='${\(Kahifu::Template::dict('KIROKU_SAKKA_PLACEHOLDER'))}'></div>";
			print "<div class='mint'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_HANTYUU'))}</span><input type='text' name='hantyuu' placeholder='${\(Kahifu::Template::dict('KIROKU_HANTYUU_PLACEHOLDER'))}'></div>";
			print "<div class='strawberry'><span class='block'>${\(Kahifu::Template::dict('KIROKU_COLLECTION'))}</span><input type='text' name='colle' placeholder='${\(Kahifu::Template::dict('KIROKU_COLLECTION_PLACEHOLDER'))}'></div>";
			print "<div class='ajisai'><span class='block'>${\(Kahifu::Template::dict('KIROKU_BIKOU'))}</span><input type='text' name='bikou' placeholder='${\(Kahifu::Template::dict('KIROKU_BIKOU_PLACEHOLDER'))}'></div>";
			print "<div class='ajisai'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_WHOLE'))}</span><input type='text' name='whole' placeholder='${\(Kahifu::Template::dict('KIROKU_WHOLE_PLACEHOLDER'))}'></div>";
			print "<div class='meadow'><span>${\(Kahifu::Template::dict('KIROKU_JOSUU'))}</span>";
				print "<select placeholder='${\(Kahifu::Template::dict('KIROKU_JOSUU_PLACEHOLDER'))}' name='josuu'>";
				print "<option value='無'>${\(Kahifu::Template::dict('NONE'))}</option>";
				for my $j (@josuu_tati){ print "<option value='$j->[1]'>$j->[0]</option>"; }
				print "</select>&nbsp;";
			print "</div>";
			print "<div class='cream'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_MIKAKUTEI'))}</span>";
				print "<div class='radio_box'><input type='radio' id='mikakutei0' name='hide' value='0'><label for='mikakutei0'>${\(Kahifu::Template::dict('KIROKU_MIKAKUTEI_OPTION_1'))}<span></span></label><input type='radio' id='mikakutei1' name='hide' value='1' checked><label for='mikakutei1'>${\(Kahifu::Template::dict('KIROKU_MIKAKUTEI_OPTION_2'))}<span></span></label></div>";
			print "</div>";
			print "<div class='cream'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_KANSYOUZUMI'))}</span>";
				print "<div class='radio_box'><input type='radio' id='kansyouzumi1' name='kansyouzumi' value='1'><label for='kansyouzumi1'>${\(Kahifu::Template::dict('KIROKU_KANSYOUZUMI_OPTION_1'))}<span></span></label><input type='radio' id='kansyouzumi0' name='kansyouzumi' value='0' checked><label for='kansyouzumi0'>${\(Kahifu::Template::dict('KIROKU_KANSYOUZUMI_OPTION_2'))}<span></span></label></div>";
			print "</div>";
			print "<div class='cream'><span class='fixed'>${\(Kahifu::Template::dict('KIROKU_YOTEI'))}</span>";
				print "<div class='radio_box'><input type='radio' id='yotei0' name='yotei' value='0' checked><label for='yotei0'>${\(Kahifu::Template::dict('KIROKU_YOTEI_OPTION_1'))}<span></span></label><input type='radio' id='yotei1' name='yotei' value='1'><label for='yotei1'>${\(Kahifu::Template::dict('KIROKU_YOTEI_OPTION_2'))}<span></span></label></div>";
			print "</div>";
			print "<div class='meadow'><span class='block'>${\(Kahifu::Template::dict('KIROKU_HAJIMARI'))}</span>";
				print "<div class='time_box'>";
				print "<input type='text' name='tosi_hajimari' placeholder='${\(date_split($imagenzai, 0))}'>${\(Kahifu::Template::dict('TOSI'))}";
				print "<input type='text' name='tuki_hajimari' placeholder='${\(date_split($imagenzai, 1))}'>${\(Kahifu::Template::dict('TUKI'))}";
				print "<input type='text' name='hi_hajimari' placeholder='${\(date_split($imagenzai, 2))}'>${\(Kahifu::Template::dict('HI'))}";
				print "<input type='text' name='ji_hajimari' placeholder='${\(date_split($imagenzai, 3))}'>${\(Kahifu::Template::dict('JI'))}";
				print "<input type='text' name='fun_hajimari' placeholder='${\(sprintf(\"%02s\", date_split($imagenzai, 4)))}'>${\(Kahifu::Template::dict('FUN'))}";
				print "<input type='text' name='unix_hajimari' placeholder='${imagenzai}'>";
				print "</div>";
			print "</div>";
			print "<div class='ajisai hazusi'><input type='submit' value='${\(Kahifu::Template::dict('KIROKU_SUBMIT'))}'></div>";
			print "</form>";
		print "</div>";
	}
	my $loop_hajime = 0;
	$loop_hajime = 1 if $page != 1;
	for(my $loop = $loop_hajime; ($loop < 2 && $ninsyou) || $loop < 1; $loop++){
		print "<div class='info'>";
		print "<div class='sakuhin'>$daimei[$loop]";
		# page in here
		print "</div>";
		print "<div class='jyou'>${\(Kahifu::Template::dict('HEADING_JYOUKYOU'))}</div>";
		print "<div class='hantyuu'>${\(Kahifu::Template::dict('HEADING_HANTYUU'))}</div>";
		print "<div class='ten'>${\(Kahifu::Template::dict('HEADING_POINT'))}</div>" if $narabi == 4;
		print "</div>";
		#print decode_utf8(param('kensaku')) if param('kensaku');
		#$dbh->trace(2); #debug sql
		push @sitazi_bind, ($page_offset) if $loop == 1;
		my $sakuhin = $dbh->prepare($meirei[$loop]);
		$sakuhin->execute(@sitazi_bind);
		while(my $v = $sakuhin->fetchrow_hashref){
		if(((not defined $v->{kakusu}) || $v->{kakusu}!=1) || Kahifu::Template::tenmei()){
			print "<div class='koumoku type_$v->{hantyuu}${\( sub { return ' hankakusi' if defined $v->{kakusu} && $v->{kakusu}==1 }->() )}'>";
				print "<div class='sakuhinmei'>";
					print "<p id='$v->{id}' class='midasi $v->{id}' data-kansou='$v->{id}'>";
					my $tekisetu_midasi = defined $v->{betumei} && $v->{betumei} ne '' && ref $v->{betumei} ne 'ARRAY' ? from_json($v->{betumei}) : $v->{midasi};
					if($sitei_gengo == 1){
						delete $tekisetu_midasi->{$Kahifu::Junbi::lang} if ref $tekisetu_midasi eq 'HASH';
					} elsif($sitei_gengo == 2 && $v->{colle} =~ /gengo_([^,]*)(,|$)/) {
						my $sakuhin_gengo = $1;
						if((grep{$_ eq $sakuhin_gengo} @kisyuutoku_gengo) ne '' && defined $v->{betumei} && $v->{betumei} ne '' && ref $v->{betumei} ne 'ARRAY'){
							delete $tekisetu_midasi->{$Kahifu::Junbi::lang};
						}
					}
					my $tekisetu_reference = ref $tekisetu_midasi eq 'HASH' && defined $tekisetu_midasi->{$Kahifu::Junbi::lang} ? $tekisetu_midasi->{$Kahifu::Junbi::lang} : (ref $tekisetu_midasi eq 'HASH' ? $v->{midasi} : $tekisetu_midasi);
					if($sitei_gengo == 1){
						delete $tekisetu_midasi->{$Kahifu::Junbi::lang} if ref $tekisetu_midasi eq 'HASH';
					} elsif($sitei_gengo == 2 && $v->{colle} =~ /gengo_([^,]*)(,|$)/) {
						my $sakuhin_gengo = $1;
						if((grep{$_ eq $sakuhin_gengo} @kisyuutoku_gengo) ne '' && defined $v->{betumei} && $v->{betumei} ne '' && ref $v->{betumei} ne 'ARRAY'){
							delete $tekisetu_midasi->{$Kahifu::Junbi::lang};
						}
					}
					print midasi_settei($tekisetu_reference, $v->{mikakutei}, $v->{current}, $kensaku);
					print "</p>";
					print "<p class='fuku_midasi $v->{id}'>$v->{fukumidasi}</p>" if $v->{fukumidasi} ne '';
					print "<span class='sakka'>" . sakka_settei($v->{sakka}, $kensaku) . "</span>" if defined $v->{sakka};				
				print "</div>";
				print "<div class='jyou'>";
					my $jyoukyou_syori = jyoukyou_settei($v->{jyoukyou}, $v->{hajimari}, $v->{owari}, $v->{current}, $v->{eternal});
					print "<div title='${\(Kahifu::Template::dict('HYOUKA_JYOU_KAISETU_' . $jyoukyou_type{$jyoukyou_syori}))}' class='jyoukyou' data-jyoutype='$v->{jyoukyou}' data-jyoukyou='$v->{id}'>";
						print "<span class='jyoukyou_type_$jyoukyou_type{$jyoukyou_syori} $jyoukyou_class{$jyoukyou_syori}'>";
						print $jyoukyou_syori;
						print "</span>";
					print "</div>";
					print "<span class='jyouhou' data-jyouhou='$v->{id}'>";
					print $v->{part};
					print defined $v->{eternal} && $v->{eternal} == 1 ? "" : "／$v->{whole}";
					print $v->{josuu};
					print "</span>";
				print "</div>";
				print "<div class='hantyuu'>";
					print "<a href='${\(url_get_tuke(\%url_get, 'id', $v->{id}))}'>";
					print "${\(Kahifu::Template::dict('HYOUKA_HANTYUU_' . $v->{hantyuu}))}";
					print "</a>";
				print "</div>";
				print "<div class='ten'>", $v->{point}, "</div>" if $narabi == 4;
				# 更新するために Initialize "activity_kousin"
				print "<div id='ak_$v->{id}' class='activity_kousin'>";
				print "<form method='post' action='kousin.pl'>";
					print "<input type='hidden' name='reference' value='$v->{id}'>";
					print "<input type='number' size='5' placeholder='${\(Kahifu::Template::dict('KOUSIN_PART_PLACEHOLDER'))}' name='part' value='$v->{part}'>";
					print "／<input type='number' size='5' placeholder='${\(Kahifu::Template::dict('KOUSIN_WHOLE_PLACEHOLDER'))}' name='whole' value='$v->{whole}'>";
					print "<select placeholder='${\(Kahifu::Template::dict('KIROKU_JOSUU_PLACEHOLDER'))}' name='josuu'>";
					for my $j (@josuu_tati){ print "<option value='$j->[1]'>$j->[0]</option>"; }
					print "</select>&nbsp;";
					print "<select placeholder='${\(Kahifu::Template::dict('HEADING_JYOUKYOU'))}' name='mode'>";
						print "<option value='0'>${\(Kahifu::Template::dict('KOUSIN_MAKASE'))}</option>";
						print "<option value='1'>${\(Kahifu::Template::dict('KOUSIN_TUMU'))}</option>";
						print "<option value='2'>${\(Kahifu::Template::dict('KOUSIN_OTOSU'))}</option>";
						print "<option value='3'>${\(Kahifu::Template::dict('KOUSIN_SAI'))}</option>";
						print "<option value='7' disabled>${\(Kahifu::Template::dict('KOUSIN_MOTO'))}</option>";
						print "<option value='4'>${\(Kahifu::Template::dict('KOUSIN_TOBU'))}</option>";
						print "<option value='5'>${\(Kahifu::Template::dict('KOUSIN_HAPPA'))}</option>";
					print "</select>　";
					print "<input type='submit' name='kiroku' value='${\(Kahifu::Template::dict('KIROKU_SUBMIT'))}'>";
					print "<div><input type='text' size='30' placeholder='${\(Kahifu::Template::dict('KOUSIN_TITLE_PLACEHOLDER'))}' name='title' value=''></div>";
					print "<div class='hiduke_collection'>";
						print "<div class='kousin_hiduke'>";
							print "<span>${\(Kahifu::Template::dict('KOUSIN_MIKAKUTEI_1'))}</span>";
							print "<input id='jikoku_mikakutei1' type='radio' name='jikoku_mikakutei' value='1'>";
							print "<label for='jikoku_mikakutei1'><span>${\(Kahifu::Template::dict('FORM_YES'))}</span></label>";
							print "<input id='jikoku_mikakutei2' type='radio' name='jikoku_mikakutei' value='0' checked='checked'>";
							print "<label for='jikoku_mikakutei2'><span>${\(Kahifu::Template::dict('FORM_NO'))}</span></label>";
							print "<span>${\(Kahifu::Template::dict('KOUSIN_MIKAKUTEI_2'))}</span>";
							print "<br>";
							print "<input type='text' size='6' placeholder='${\(date_split($imagenzai, 0))}' name='tosi_owari'>";
							print "<input type='text' size='3' placeholder='${\(date_split($imagenzai, 1))}' name='tuki_owari'>";
							print "<input type='text' size='3' placeholder='${\(date_split($imagenzai, 2))}' name='hi_owari'>";
							print "<input type='text' size='3' placeholder='${\(date_split($imagenzai, 3))}' name='ji_owari'>";
							print "<input type='text' size='3' placeholder='${\(sprintf(\"%02s\", date_split($imagenzai, 4)))}' name='fun_owari'>";
							print "<br>";
							print "<input type='text' size='29' placeholder='$imagenzai' name='unix_owari' value=''>";
						print "</div>";
						print "<div class='hajimari_hiduke'>";
							print "<span>${\(Kahifu::Template::dict('KOUSIN_HAJIMARI'))}</span>";
							print "<br>";
							print "<input type='text' size='6' placeholder='${\(date_split($v->{hajimari}, 0))}' name='tosi_hajimari'>";
							print "<input type='text' size='3' placeholder='${\(date_split($v->{hajimari}, 1))}' name='tuki_hajimari'>";
							print "<input type='text' size='3' placeholder='${\(date_split($v->{hajimari}, 2))}' name='hi_hajimari'>";
							print "<input type='text' size='3' placeholder='${\(date_split($v->{hajimari}, 3))}' name='ji_hajimari'>";
							print "<input type='text' size='3' placeholder='${\(sprintf(\"%02s\", date_split($v->{hajimari}, 4)))}' name='fun_hajimari'>";
							print "　";
							print "<input type='text' size='3' placeholder='${\(Kahifu::Template::dict('KOUSIN_JUNNI'))}' name='junni'>";
							print "<br>";
							print "<input type='text' size='29' placeholder='$v->{hajimari}' name='unix_hajimari' value=''>";
						print "</div>";
						print "<div class='sakujyo'>";
							print "<span>${\(Kahifu::Template::dict('SAKUJYO'))}</span>";
							print "<br>";
							print "<input type='submit' name='sakujyo' value='${\(Kahifu::Template::dict('SAKUJYO'))}'>&nbsp;";
							print "<input type='submit' name='touroku_sakujyo' value='${\(Kahifu::Template::dict('TOUROKU_SAKUJYO'))}'>";
						print "</div>";
					print "</div>";
				print "</form>";
				print "</div>";
				# 履歴を初期化する Initialize "rireki"
				print "<div id='a_$v->{id}' class='activity'>";
				print "<div class='rireki_kakera'><div class='rirekinai_jyoukyou'><div class='jyoukyou'><span class='jyoukyou_type_1'>${\(Kahifu::Template::dict('HAJIMARI_JYOU'))}</span></div></div><div class='rirekinai_hiduke${\( sub { return ' mikakutei\'><span class=\'mikakutei_kome\'>※</span><span class=\'' if $v->{mikakutei}==1 }->() )}'>", date($v->{hajimari}, $v->{mikakutei}, 1),"</span></div></div>";
				my $kansyou_kaisuu = 0;
				foreach(@r){
					if ($_->[1] == $v->{id}){
						print "<div class='rireki_kakera'>";
							print "<div class='rirekinai_jyoukyou'>";
								print "<div title='${\(Kahifu::Template::dict('HYOUKA_JYOU_KAISETU_' . $jyoukyou_type{$jyoukyou_syori}))}' class='jyoukyou'>";
								my $jyoukyou_syori = jyoukyou_settei($_->[5], $_->[2], $_->[2], 609, 609);
								print "<span class='jyoukyou_type_$jyoukyou_type{$jyoukyou_syori} $jyoukyou_class{$jyoukyou_syori}'>";
								print $jyoukyou_syori;
								print "</div>";
								$kansyou_kaisuu++ if $_->[5] eq '終';
								print "<span class='kaisuu'>${\(Kahifu::Infra::nihon_suuji($kansyou_kaisuu))}</span>" if defined $kansyou_kaisuu && $kansyou_kaisuu > 1 && $_->[5] eq '終';
							print "</div>";
							print "<div title='", date_split($_->[2], 8, 1),"' class='rirekinai_hiduke'>";
							print $_->[7] == 1 ? "<span class='mikakutei_kome'>※</span>" : "";
							print date($_->[2], $_->[7], 1);
							print "</div>";
							print "<div class='rirekinai_sinkou'>";
							print $_->[3];
							print defined $v->{eternal} && $v->{eternal} == 1 ? "" : "／$_->[4]";
							print $_->[6];
							print "</div>";
							print "<div class='rireki_title'>";
							print $_->[8];
							print "</div>";
						print "</div>";
					}
				}
				print "</div>";
				# 感想箱（kansou）を初期化
				print "<div class='kansou' data-kansou='$v->{id}'>";
					#print "<p>";
					print Kahifu::Infra::bunsyou($v->{kansou}) if defined $v->{kansou};
					print "<a class='tuduki' href='${\(url_get_tuke(\%url_get, 'id', $v->{id}))}'>${\(Kahifu::Template::dict('KANSOU_TUDUKI'))}</a>" if defined $v->{extend} && $v->{extend} == 1;
					#print "</p>";
				print "</div>";
				# 作品編集箱（kansou_kousin）を初期化
				print "<div id='kk_$v->{id}' class='kansou_kousin'>";
					print "<form id='kansou_$v->{id}' method='post' action='kansou.pl' >";
					print "<input type='hidden' name='reference' value='$v->{id}'>";
					print "<div class='midasi_kousin'>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_TITLE'))}</div><div><input type='text' size='30' placeholder='$v->{midasi}' name='midasi' value='$v->{midasi}'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_HANTYUU'))}</div><div><input type='text' size='15' placeholder='$v->{hantyuu}' name='hantyuu' value='", ${\(Kahifu::Template::dict('HYOUKA_HANTYUU_' . $v->{hantyuu}))}//'', "'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_SUBTITLE'))}</div><div><input type='text' size='30' placeholder='", $v->{fukumidasi}//'', "' name='fukumidasi' value='", $v->{fukumidasi}//'', "'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_SAKKA'))}</div><div><input type='text' size='20' placeholder='", $v->{sakka}//'', "' name='sakka' value='", $v->{sakka}//'', "'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_BETUMEI'))}</div><div><input type='text' size='20' name='kanri' value=''></div></div>";
					print "</div>";
					print "<div class='betumei'>";
						print "<div>${\(Kahifu::Template::dict('KIROKU_BETUMEI'))}</div>";
						print "<div class='betumei_set'>";
							my $betumei = defined $v->{betumei} && $v->{betumei} ne '' && ref $v->{betumei} ne 'HASH' ? from_json($v->{betumei}) : "";
							if(defined $v->{betumei} && $v->{betumei} ne '' && ref($v->{betumei}) ne 'ARRAY'){
								foreach my $key ( keys %$betumei ) { 
									print "<div class='betumei_block'>";
									print "<input name='betumei_key' placeholder='${key}' value='${key}'>";
			   						print "<input name='betumei_val' placeholder=\"", $betumei->{$key}, "\" value=\"", $betumei->{$key}, "\"><button class='betumei_sakujyo' type='button'>–</button>";
									print "</div>";
								}
							} else {
								print "<div class='betumei_block'><input name='betumei_key' value=''><input name='betumei_val' value=''><button class='betumei_sakujyo' type='button'>–</button></div>";
							}
							print "<button class='betumei_tuika' type='button'>＋</button>";
						print "</div>";
					print "</div>";
					print "<div class='extra'>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_THEME'))}</div><div><input type='text' size='20' placeholder='", $v->{theme}//'', "' name='theme' value='", $v->{theme}//'', "'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_GYOUSUU'))}</div><div><input type='text' size='20' placeholder='", $v->{gyousuu}//'', "' name='gyousuu' value='${\(sub { return $v->{gyousuu} if defined $v->{gyousuu} }->())}'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_BG_IMG'))}</div><div><input type='text' size='40' placeholder='", $v->{bg_img}//'', "' name='bg_img' value='", $v->{bg_img}//'', "'></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_ETERNAL'))}</div><div><input id='mugen$v->{id}1' type='radio' name='eternal' value='1'${\( sub { return 'checked=checked' if defined $v->{eternal} && $v->{eternal}==1 }->() )}><label for='mugen$v->{id}1'>${\(Kahifu::Template::dict('IRI'))}</label><input id='mugen$v->{id}2' type='radio' name='eternal' value='0'${\( sub { return 'checked=checked' if defined $v->{eternal} && $v->{eternal}==0 || not defined $v->{eternal} }->() )}><label for='mugen$v->{id}2'>${\(Kahifu::Template::dict('KIRI'))}</label></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_CURRENT'))}</div><div><input id='current$v->{id}1' type='radio' name='current' value='1'${\( sub { return 'checked=checked' if defined $v->{current} && $v->{current}==1 }->() )}><label for='current$v->{id}1'>${\(Kahifu::Template::dict('AGE'))}</label><input id='current$v->{id}2' type='radio' name='current' value='0'${\( sub { return 'checked=checked' if defined $v->{current} && $v->{current}==0 || not defined $v->{current} }->() )}><label for='current$v->{id}2'>${\(Kahifu::Template::dict('KIRI'))}</label><input id='current$v->{id}3' type='radio' name='current' value='2'${\( sub { return 'checked=checked' if defined $v->{current} && $v->{current}==2 }->() )}><label for='current$v->{id}3'>${\(Kahifu::Template::dict('SAGE'))}</label><input id='current$v->{id}4' type='radio' name='current' value='3'${\( sub { return 'checked=checked' if defined $v->{current} && $v->{current}==3 }->() )}><label for='current$v->{id}4'>${\(Kahifu::Template::dict('DARAKU'))}</label></div></div>";
					print "</div>";
					print "<div class='super_extra'>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_MIKAKUTEI_ALT'))}</div><div><input id='mikakutei$v->{id}1' type='radio' name='mikakutei' value='1'${\( sub { return 'checked=checked' if defined $v->{mikakutei} && $v->{mikakutei}==1 }->() )}><label for='mikakutei$v->{id}1'>${\(Kahifu::Template::dict('IRI'))}</label><input id='mikakutei$v->{id}0' type='radio' name='mikakutei' value='0'${\( sub { return 'checked=checked' if defined $v->{mikakutei} && $v->{mikakutei}==0 || not defined $v->{mikakutei} }->() )}><label for='mikakutei$v->{id}0'>${\(Kahifu::Template::dict('KIRI'))}</label></div></div>";
						print "<div><div>${\(Kahifu::Template::dict('KIROKU_OFFSET'))}</div><input type='number' min='0' size='4' placeholder='", $v->{offset}//'', "' name='offset' value='", $v->{offset}//'', "'></div>";
						print "<div class='yotei'><div>${\(Kahifu::Template::dict('KIROKU_YOTEI_ALT'))}</div><div><input id='yotei$v->{id}1' type='radio' name='yotei' value='1'${\( sub { return 'checked=checked' if defined $v->{yotei} && $v->{yotei}==1 }->() )}><label for='yotei$v->{id}1'>${\(Kahifu::Template::dict('IRI'))}</label><input id='yotei$v->{id}0' type='radio' name='yotei' value='0'${\( sub { return 'checked=checked' if defined $v->{yotei} && $v->{yotei}==0 || not defined $v->{yotei} }->() )}><label for='yotei$v->{id}0'>${\(Kahifu::Template::dict('KIRI'))}</label></div></div>" if $v->{part} == 0;
					print "</div>";
					print "<div class='colle'><div><div>${\(Kahifu::Template::dict('KIROKU_COLLECTION_ALT'))}</div><div><input type='text' size='30' name='collection' placeholder='' value='", $v->{colle}//'', "'></div></div></div>";
					print "<div class='bunsyou'><textarea name='kansou' form='kansou_$v->{id}'>", $v->{kansou}//'', "</textarea></div>";
					print "<div class='meirei'><input type='submit' name='kousin' value='${\(Kahifu::Template::dict('KIROKU_KOUSIN'))}'></div>";
					print "</form>";
				print "</div>";
			print "</div>";
		} # if kakusu etc.
		}	# while sakuhin…
	}
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
} elsif($paginate == 2){
	#　コレクション（蒐集・殿堂欄）
	#　PAGINATE=2
	#
	my ($midasi_recall, $meisyou_recall, $hyouji_ja, $hyouji_en, $turu_recall, $tag_recall, $gaiyouran_recall, $bikou_recall, $hide_recall, $bikouiti_recall, $kansou_hyouji_recall);
	if(Kahifu::Template::tenmei()){
		if(defined param('collection')){
			my $meirei = ("select * from collection where `id` = ?");
			my $collection_sitami = $dbh->prepare($meirei);
			my $collection_id = (defined param('collection')) ? param('collection') : '1';
			$collection_sitami->execute($collection_id);
			my $v = $collection_sitami->fetchrow_hashref;
			$midasi_recall = $v->{midasi};
			$meisyou_recall = $v->{midasi_seisiki};
			my $hyouji_recall = $v->{hyouji};
			my $unserialize_hyouji = from_json($hyouji_recall);
			$hyouji_ja = $unserialize_hyouji->{ja};
			$hyouji_en = $unserialize_hyouji->{en};
			$turu_recall = $v->{turu};
			$tag_recall = $v->{tag};
			$gaiyouran_recall = $v->{gaiyouran};
			my $bikou_get = $v->{bikou};
			my $bikou_unserialized = from_json($bikou_get);
			if(ref($bikou_unserialized) ne "ARRAY"){
				foreach my $key ( keys %$bikou_unserialized ) { 
			   	$bikou_recall .= $key . "::" . $bikou_unserialized->{$key} . "++\n";
				}
			} else { $bikou_recall = ""; }
			$bikouiti_recall = $v->{bikouiti};
			$hide_recall = $v->{hide};
			$kansou_hyouji_recall = $v->{kansou_hyouji};
		}
		print "<div data-kakejiku='colle_info' class='kakejiku colle_info'>";
			print "<span>${\(Kahifu::Template::dict('COLLE_SINSYUKU'))}<span class='sinsyuku'>${\(Kahifu::Template::dict('SINSYUKU_PLUS'))}</span></span>";
		print "</div>";
		print "<div data-kakejiku='colle_info' class='form colle_info'>";
			print "<form id='collection_form' method='post' action='collection.pl'>";
			print "<div class='cream'><span class='block'>${\(Kahifu::Template::dict('COLLE_MIDASI'))}</span><input type='text' name='midasi' placeholder='見出し' value='${\(sub { return $midasi_recall if defined $midasi_recall }->())}'></div>";
			print "<div class='cream'><span class='block'>${\(Kahifu::Template::dict('COLLE_MIDASI_SEISIKI'))}</span><input type='text' name='midasi_seisiki' placeholder='正式名称' value='${\(sub { return $meisyou_recall if defined $midasi_recall }->())}'></div>";
			print "<div class='ajisai'><span class='block'>${\(Kahifu::Template::dict('COLLE_HYOUJI_JA'))}</span><input type='text' name='hyouji/ja' placeholder='日本語の何か' value='${\(sub { return $hyouji_ja if defined $hyouji_ja }->())}'></div>";
			print "<div class='ajisai'><span class='block'>${\(Kahifu::Template::dict('COLLE_HYOUJI_EN'))}</span><input type='text' name='hyouji/en' placeholder='英語の何か' value='${\(sub { return $hyouji_en if defined $hyouji_en }->())}'></div>";
			print "<div class='strawberry'><span class='block'>${\(Kahifu::Template::dict('COLLE_TURU'))}</span><input type='text' name='turu' placeholder='1,2,4,7' value='${\(sub { return $turu_recall if defined $turu_recall }->())}'></div>";
			print "<div class='mint'><span class='block'>${\(Kahifu::Template::dict('COLLE_TAG'))}</span><input type='text' name='tag' placeholder='award' value='${\(sub { return $tag_recall if defined $tag_recall }->())}'></div>";
			print "<div class='ajisai'><span class='fixed'>${\(Kahifu::Template::dict('COLLE_DESCRIPTION'))}</span><textarea form='collection_form' name='gaiyouran'>${\(sub { return $gaiyouran_recall if defined $gaiyouran_recall }->())}</textarea></div>";
			print "<div class='mint'><span class='block'>${\(Kahifu::Template::dict('COLLE_BIKOU'))}</span><textarea form='collection_form' name='bikou'>${\(sub { return $bikou_recall if defined $bikou_recall }->())}</textarea></div>";
			print "<div class='cream'><span>${\(Kahifu::Template::dict('COLLE_KAKUSU'))}</span>";
				print "<div class='radio_box'><input type='radio' id='collekakusu0' name='hide' value='0'${\( sub { return ' checked=checked' if defined $hide_recall && $hide_recall == 0 || not defined $hide_recall }->() )}><label for='collekakusu0'>${\(Kahifu::Template::dict('COLLE_KAKUSU_OPTION_1'))}<span></span></label><input type='radio' id='collekakusu1' name='hide' value='1' ${\( sub { return ' checked=checked' if defined $hide_recall && $hide_recall == 1 }->() )}><label for='collekakusu1'>${\(Kahifu::Template::dict('COLLE_KAKUSU_OPTION_2'))}<span></span></label></div>";
			print "</div>";
			print "<div class='cream'><span>${\(Kahifu::Template::dict('COLLE_BIKOUITI'))}</span>";
				print "<div class='radio_box'><input type='radio' id='bikoustyle1' name='bikouiti' value='1'${\( sub { return ' checked=checked' if defined $bikouiti_recall && $bikouiti_recall==1 }->() )}><label for='bikoustyle1'><span>${\(Kahifu::Template::dict('HIDARI'))}</span></label><input type='radio' id='bikoustyle0' name='bikouiti' value='0'${\( sub { return ' checked=checked' if defined $bikouiti_recall && $bikouiti_recall==0 || not defined $bikouiti_recall }->() )}><label for='bikoustyle0'>${\(Kahifu::Template::dict('MIGI'))}<span></span></label><input type='radio' id='bikoustyle2' name='bikouiti' value='2'${\( sub { return ' checked=checked' if defined $bikouiti_recall && $bikouiti_recall==2 }->() )}><label for='bikoustyle2'><span>${\(Kahifu::Template::dict('UE'))}</span></label><input type='radio' id='bikoustyle3' name='bikouiti' value='3'${\( sub { return ' checked=checked' if defined $bikouiti_recall && $bikouiti_recall==3 }->() )}><label for='bikoustyle3'>${\(Kahifu::Template::dict('SITA'))}<span></span></label></div>";
			print "</div>";
			print "<div class='cream'><span>${\(Kahifu::Template::dict('COLLE_KANSOU_HYOUJI'))}</span>";
				print "<div class='radio_box'><input type='radio' id='kansouhyouji0' name='kansou_hyouji' value='0'${\( sub { return ' checked=checked' if defined $kansou_hyouji_recall && $kansou_hyouji_recall==0 || not defined $kansou_hyouji_recall }->() )}><label for='kansouhyouji0'><span>${\(Kahifu::Template::dict('HIHYOUJI'))}</span></label><input type='radio' id='kansouhyouji1' name='kansou_hyouji' value='1'${\( sub { return ' checked=checked' if defined $kansou_hyouji_recall && $kansou_hyouji_recall==1 }->() )}><label for='kansouhyouji1'>${\(Kahifu::Template::dict('HYOUJI'))}<span></span></label></div>";
			print "</div>";
			print "<div class='ajisai hazusi'><input type='submit' name='${\( sub { return defined param('collection') ? 'colle_hensyuu' : 'colle_sinkiroku' }->() )}' value='${\(Kahifu::Template::dict('COLLE_SUBMIT'))}'></div>";
			print "</form>";
		print "</div>";
	}
	if(defined param('collection')){
		#　コレクション内 （Inside the collection）
		my $meirei = ("select * from collection where `id` = ?");
		my $collection = $dbh->prepare($meirei);
		my $collection_id = (defined param('collection')) ? param('collection') : '1';
		$collection->execute($collection_id);
		my $v = $collection->fetchrow_hashref;
		# 蔓の内容を決まる、特にspecial scenario colle=1
		my (@turu, $turu_sitazi);
		my %jyoukyou_colle;
		if($v->{id} == 1){
			# 予定欄の蔓を設定
			my $turu_meirei = "select saku.`id` from sakuhin saku left join rireki reki on reki.sid = saku.id where reki.sid is null order by saku.`time` desc";
			@turu = $dbh->selectall_array($turu_meirei);
			for(my $i=0; $i<scalar(@turu); $i++){$turu[$i] = $turu[$i][0]}
		} elsif($v->{midasi_seisiki} eq 'watchlist') {
			my $turu_meirei = "select saku.`id` from sakuhin saku left join rireki reki on reki.sid = saku.id where reki.sid is null and saku.`yotei` = 1 order by saku.`time` desc";
			@turu = $dbh->selectall_array($turu_meirei);
			for(my $i=0; $i<scalar(@turu); $i++){$turu[$i] = $turu[$i][0]}
		} else {
			@turu = split /,/,$v->{turu};
		}
		for(my $i=0; $i<scalar(@turu); $i++){$turu_sitazi .= '?,'}
		$turu_sitazi =~ s/,\s*$//; #　後端のコンマを削除す
		$turu_sitazi = '0' if not defined $turu_sitazi;
		#　備考を決まる
		my $bikou = from_json($v->{bikou});
		#　第二次命令　→作品欄から抽出す
		my $dainiji_meirei = ("select * from sakuhin where `id` in (${turu_sitazi}) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi} order by field (id, ${turu_sitazi})");
		my $sakuhinran = $dbh->prepare($dainiji_meirei);
		$sakuhinran->execute(@turu, @sitazi_bind, @turu);
		print "<div class='colle navi'>";
		print "</div>";
		print "<div class='colle heading'>";
			print "<span>";
			print midasi_settei($v->{midasi});
			print defined $v->{hyouji} && $v->{hyouji} && (defined from_json($v->{hyouji})->{$Kahifu::Junbi::lang}) && (from_json($v->{hyouji})->{$Kahifu::Junbi::lang}) && (from_json($v->{hyouji})->{$Kahifu::Junbi::lang} ne $v->{midasi}) ? "<span class='honnyaku'>${\(from_json($v->{hyouji})->{$Kahifu::Junbi::lang})}</span>" : "";
			print "</span>";
		print "</div>";
		print "<div class='colle gaiyouran'>";
			print Kahifu::Infra::bunsyou($v->{gaiyouran}) if defined $v->{gaiyouran};
		print "</div>";
		print "<form id='colle_box' method='post' action='narabikae.pl'>" if defined param('hensyuu');
		print "<div class='control'><input type='submit' name='saisettei' value='${\(Kahifu::Template::dict('COLLE_SAISETTEI'))}'></div>" if defined param('hensyuu');
		print "<input type='hidden' name='collection' value='$v->{id}'>";
		while(my $w = $sakuhinran->fetchrow_hashref){
			print "<div class='colle koumoku bikou_$v->{bikouiti} type_$w->{hantyuu}'>";
				print "<input type='hidden' name='junban' value='$w->{id}'>";
				print "<div class='sakuhinmei bikou_$v->{bikouiti}'>";
					print "<div class='omake id'><span>$w->{id}</span></div>" if defined param('hensyuu');
					print "<div class='bikou ue'><span>$bikou->{$w->{id}}</span></div>" if $v->{bikouiti} == 2;
					print "<div class='bikou hidari'><span>$bikou->{$w->{id}}</span></div>" if $v->{bikouiti} == 1;
					print "<div>";
						print "<p id='$w->{id}' class='midasi $w->{id}' data-kansou='$w->{id}'>";
						print "<a href='${\(url_get_tuke(\%url_get, 'id', $w->{id}))}'>";
						my $tekisetu_midasi = defined $w->{betumei} && $w->{betumei} ne '' && ref $w->{betumei} ne 'ARRAY' ? from_json($w->{betumei}) : $w->{midasi};
						if($sitei_gengo == 1){
							delete $tekisetu_midasi->{$Kahifu::Junbi::lang} if ref $tekisetu_midasi eq 'HASH';
						} elsif($sitei_gengo == 2 && $w->{colle} =~ /gengo_([^,]*)(,|$)/) {
							my $sakuhin_gengo = $1;
							if((grep{$_ eq $sakuhin_gengo} @kisyuutoku_gengo) ne '' && defined $w->{betumei} && $w->{betumei} ne '' && ref $w->{betumei} ne 'ARRAY'){
								delete $tekisetu_midasi->{$Kahifu::Junbi::lang};
							}
						}
						my $tekisetu_reference = ref $tekisetu_midasi eq 'HASH' ? $tekisetu_midasi->{$Kahifu::Junbi::lang} : (ref $tekisetu_midasi eq 'HASH' ? $w->{midasi} : $tekisetu_midasi);
						print midasi_settei($tekisetu_reference, $w->{mikakutei}, $w->{current}, $kensaku);
						print "</a>";
						print "</p>";
						print "<p class='fuku_midasi $w->{id}'>$w->{fukumidasi}</p>" if $w->{fukumidasi} ne '';
						my $sakka_hyouji = Kahifu::Infra::mobile() ? 0 : 1;
						print "<p class='sakka'>" . sakka_settei($w->{sakka}, $kensaku, $sakka_hyouji) . "</p>" if defined $w->{sakka};	
					print "</div>";			
				print "</div>";
				print "<div class='jyou'>";
					print "<div class='jyoukyou' data-jyoutype='$w->{jyoukyou}' data-jyoukyou='$w->{id}'>";
						my $jyoukyou_syori = jyoukyou_settei($w->{jyoukyou}, $w->{hajimari}, $w->{owari}, 90, $w->{eternal});
						print "<span class='jyoukyou_type_$jyoukyou_type{$jyoukyou_syori} $jyoukyou_class{$jyoukyou_syori}'>";
						print $jyoukyou_syori;
						$jyoukyou_colle{$jyoukyou_syori}++;
						print "</span>";
					print "</div>";
					print "<span class='jyouhou' data-jyouhou='$w->{id}'>";
					print $w->{part};
					print defined $w->{eternal} && $w->{eternal} == 1 ? "" : "／$w->{whole}";
					print $w->{josuu};
					print "</span>";
				print "</div>";
				print "<div class='hantyuu'>";
					print "${\(Kahifu::Template::dict('HYOUKA_HANTYUU_' . $w->{hantyuu}))}";
				print "</div>";
				print "<div class='bikou migi'><span>${\( sub { return $bikou->{$w->{id}} if ref($bikou) ne 'ARRAY' }->() )}</span></div>" if !defined param('hensyuu') && (! defined $v->{bikouiti} || defined $v->{bikouiti} && $v->{bikouiti} eq 0) && ref($bikou) ne 'ARRAY' && defined $bikou->{$w->{id}};
				print "<div class='bikou migi'><textarea rows=1 id='colle_box' name='test'>", ${\( sub { return $bikou->{$w->{id}} if ref($bikou) ne 'ARRAY' }->() )},"</textarea></div>" if defined param('hensyuu');
				print "<div class='bikou sita'>$bikou->{$w->{id}}</div>" if $v->{bikouiti} == 3;
				print "<div class='kansou' data-kansou='$v->{id}'>";
					print Kahifu::Infra::bunsyou($w->{kansou}) if defined $v->{kansou_hyouji} && $v->{kansou_hyouji} == 1;
				print "</div>";
			print "</div>";
		}
		print "</form>" if defined param('hensyuu'); #form id=colle_box
		print "<div class='colle youyaku'>";
			while(my($k, $v) = each %jyoukyou_colle) {
				print "<div class='jyoukyou'><span class='jyoukyou_type_$jyoukyou_type{$k} $jyoukyou_class{$k}'>${k}&nbsp;${v}</span></div>";
			}
		print "</div>";
		print "<script>
			Sortable.create(colle_box, {
				filter: '.control',
				animation: 100,
				delay: 250,
				delayOnTouchOnly: true
			});
		</script>";
	} else {
		#　一覧コレクション外 （Collection listing）	
		#my $meirei = "select id, midasi, hyouji, turu, color from collection";
		my $meirei = ("select id, midasi, midasi_seisiki, tag, hyouji, turu, color from collection order by field(`tag`, 'yotei', 'favorite', 'award', 'waku', 'misc', 'period', 'tag'), `sort1` asc, `sort2` asc");
		my $colleran = $dbh->prepare($meirei);
		print "<div>";
		print "</div>";
		$colleran->execute();
		print "<div class='collection_box'>";
		while(my $v = $colleran->fetchrow_hashref){
			print "<div class='koumoku type_$v->{color}'>";
				print "<div class='midasi'>";
					print "<span>";
					print "<a href='${\(url_get_tuke(\%url_get, 'collection', $v->{id}))}'>";
					print defined $v->{hyouji} && $v->{hyouji} && defined from_json($v->{hyouji})->{$Kahifu::Junbi::lang} && from_json($v->{hyouji})->{$Kahifu::Junbi::lang} ? midasi_settei(from_json($v->{hyouji})->{$Kahifu::Junbi::lang}, 0, 0, $kensaku) : midasi_settei($v->{midasi}, 0, 0, $kensaku);
					print "</a>";
					print "</span>";
				print "</div>";
				print "<div class='count'>";
					if($kensaku && ($v->{turu} ne '' || ($v->{turu} eq '' && $v->{tag} eq 'yotei'))){
						my @sakuhin_colle;
						if($v->{id}==1){
							my $turu_meirei = "select saku.`id` from sakuhin saku left join rireki reki on reki.sid = saku.id where reki.sid is null order by saku.`time` desc";
							@sakuhin_colle = $dbh->selectall_array($turu_meirei);
							for(my $i=0; $i<scalar(@sakuhin_colle); $i++){$sakuhin_colle[$i] = $sakuhin_colle[$i][0]}
						} elsif($v->{midasi_seisiki} eq 'watchlist') {
							my $turu_meirei = "select saku.`id` from sakuhin saku left join rireki reki on reki.sid = saku.id where reki.sid is null and saku.`yotei` = 1 order by saku.`time` desc";
							@sakuhin_colle = $dbh->selectall_array($turu_meirei);
							for(my $i=0; $i<scalar(@sakuhin_colle); $i++){$sakuhin_colle[$i] = $sakuhin_colle[$i][0]}
						} else {
							@sakuhin_colle = split ',', $v->{turu};
						}
						my $colle_placeholders = join ", ", ("?") x @sakuhin_colle;
						my $colle_meirei = "select count(*) from sakuhin where `id` in($colle_placeholders) ${kensaku_sitazi} ${hantyuu_sibori_sitazi} ${jyoukyou_sibori_sitazi}";
						my $kensuu_collebetu = $dbh->prepare($colle_meirei);
						$kensuu_collebetu->execute(@sakuhin_colle, @sitazi_bind);
						my $row_count = $kensuu_collebetu->fetchall_arrayref();
						print $row_count->[0][0], '件';
					} else {
						print my $row_count = scalar(split(/,/,$v->{turu})), '件' if $v->{tag} ne 'yotei';
					}
				print "</div>";
			print "</div>";
		}
		print "</div>"; #div.collection_box
	}
} elsif ($paginate == 3){
	#　PAGINATE=3
	#　履歴　RIREKI
	$rirekiran = $dbh->prepare($meirei[0]);
	$rirekiran->execute($week_limit_lower, $week_limit_upper, @sitazi_bind, $week_limit_lower, $week_limit_upper, @sitazi_bind);
	sub ongaku_sounyuu {
		my $last_sakuhin = shift;
		my $saigentei = shift; 
		my $teigentei = shift;
		#はい、お借りしまーす！
		my @listen_time = reverse @{$_[0]};
		my @listen_info_artist = reverse @{$_[1]};
		my @listen_info_album = reverse @{$_[2]};
		my @listen_info_track = reverse @{$_[3]};
		for my $p (0 .. scalar @listen_time){
			if($listen_time[$p] < $saigentei && $listen_time[$p] >= $teigentei){
				#　音楽セッションを挿入す
				my $artist_json = from_json($listen_info_artist[$p]);
				my $album_json = from_json($listen_info_album[$p]);
				my $track_json = from_json($listen_info_track[$p]);
				my $max_artist = (sort {$artist_json->{$a} <=> $artist_json->{$b}} keys %$artist_json)[-1];
				my $max_artist_nii = (sort {$artist_json->{$a} <=> $artist_json->{$b}} keys %$artist_json)[-2] if scalar %$artist_json > 1;
				my $max_artist_sanni = (sort {$artist_json->{$a} <=> $artist_json->{$b}} keys %$artist_json)[-3] if scalar %$artist_json > 2;
				my $max_album = (sort {$album_json->{$a} <=> $album_json->{$b}} keys %$album_json)[-1];
				my $max_track = (sort {$track_json->{$a} <=> $track_json->{$b}} keys %$track_json)[-1];
				my $track_total = sum values %$track_json; # 再生数("scrobble") VS 曲数
				print "<div class='koumoku ongaku lang_${Kahifu::Junbi::lang}'>";
					print "<div title='${\(date_split($listen_time[$p], 8, $sanjyuujikan_seido))}' class='hiduke'>";
						print "<span>${\(date_split($listen_time[$p], 7))}</span>";
						print "<span class='jikantai'>${\(jikantai($listen_time[$p], $sanjyuujikan_seido))}</span>" if $Kahifu::Junbi::lang eq 'ja' && $ninsyou;
					print "</div>";
					print "<div class='sakuhinmei'>";
						print "<p class='midasi'>";
							if($track_json->{$max_track} != $track_total && $album_json->{$max_album} * 1.25 > $track_total){
								print $max_artist if $artist_json->{$max_artist} * 1.25 > $track_total;
								print "${\(Kahifu::Template::dict('KAGIKAKKO_HIDARI'))}", $max_album, "${\(Kahifu::Template::dict('KAGIKAKKO_MIGI'))}";
								print "${\(Kahifu::Template::dict('NADO'))}" if scalar %$album_json > 1;
							} else {
								print $max_artist;
								if($track_json->{$max_track} * 2 > $track_total){
									print "${\(Kahifu::Template::dict('KAGIKAKKO_HIDARI'))}", $max_track, "${\(Kahifu::Template::dict('KAGIKAKKO_MIGI'))}";
									print "${\(Kahifu::Template::dict('NADO'))}" if scalar %$track_json > 1;
								} else {
									print defined $max_artist_nii && ($artist_json->{$max_artist_nii} * 2 >= $artist_json->{$max_artist}) ? "、${max_artist_nii}" : (%$artist_json == 2 ? "${\(Kahifu::Template::dict('NADO'))}" : "");
									print defined $max_artist_sanni && ($artist_json->{$max_artist_sanni} * 2 >= $artist_json->{$max_artist}) ? "、${max_artist_sanni}" : (%$artist_json == 3 ? "${\(Kahifu::Template::dict('NADO'))}" : "");
									print "${\(Kahifu::Template::dict('NADO'))}" if scalar %$artist_json > 3;
								}
							}
						print "</p>";
					print "</div>";
					print "<div class='jyou'>";
						print "<div class='jyoukyou'>";
							print "<span class='onpu'>";
							print '聴';
							print "</span>";
						print "</div>";
						print "<span class='jyouhou'>";
						print scalar %$track_json, "曲／", scalar %$artist_json, "名／", scalar %$album_json, "枚";
						print "</span>";
					print "</div>";
				print "</div>";
				$last_sakuhin = 0;
			}
		}
		return $last_sakuhin;
	}

	print "<div class='rireki_box'>";
		my ($last_sakuhin, $rireki_row_count);
		my $last_timestamp = $week_limit_upper;
		while(my $v = $rirekiran->fetchrow_hashref){
			$rireki_row_count++;
			$last_sakuhin = ongaku_sounyuu($last_sakuhin, $last_timestamp, $v->{jiten}, \@listen_time, \@listen_info_artist, \@listen_info_album, \@listen_info_track);
			print "<div class='koumoku type_$v->{hantyuu}${\( sub { return ' hankakusi' if defined $v->{kakusu} && $v->{kakusu}==1 }->() )} lang_${Kahifu::Junbi::lang}'>";
				print "<div title='${\(date_split($v->{jiten}, 8, $sanjyuujikan_seido))}' class='hiduke${\( sub { return ' hankakusi' if defined $v->{mkt} && $v->{mkt}==1 }->() )} '>";
					print "<span>${\(date_split($v->{jiten}, 7, $sanjyuujikan_seido))}</span>";
					print "<span class='jikantai'>${\(jikantai($v->{jiten}, $sanjyuujikan_seido))}</span>" if $Kahifu::Junbi::lang eq 'ja' && $ninsyou;
				print "</div>";
				print "<div class='sakuhinmei'>";
					print "<span class='syurui type_$v->{jyoukyou}'>", Kahifu::Template::dict('KUTIKOMI_TYPE_'.$v->{jyoukyou}), "</span>" if $v->{hantyuu} == 700 && !Kahifu::Infra::mobile();
					print "<p id='$v->{id}' class='midasi $v->{id}' data-kansou='$v->{id}'>";
					my $tekisetu_midasi = defined $v->{betumei} && $v->{betumei} ne '' && ref $v->{betumei} ne 'ARRAY' ? from_json($v->{betumei}) : $v->{midasi};
					if($sitei_gengo == 1){
						delete $tekisetu_midasi->{$Kahifu::Junbi::lang} if ref $tekisetu_midasi eq 'HASH';
					} elsif($sitei_gengo == 2 && $v->{colle} =~ /gengo_([^,]*)(,|$)/) {
						my $sakuhin_gengo = $1;
						if((grep{$_ eq $sakuhin_gengo} @kisyuutoku_gengo) ne '' && defined $v->{betumei} && $v->{betumei} ne '' && ref $v->{betumei} ne 'ARRAY'){
							delete $tekisetu_midasi->{$Kahifu::Junbi::lang};
						}
					}
					my $tekisetu_reference = ref $tekisetu_midasi eq 'HASH' && defined $tekisetu_midasi->{$Kahifu::Junbi::lang} ? $tekisetu_midasi->{$Kahifu::Junbi::lang} : (ref $tekisetu_midasi eq 'HASH' ? $v->{midasi} : $tekisetu_midasi);
					print midasi_settei($tekisetu_reference, $v->{mikakutei}, $v->{current}, $kensaku) if (defined $last_sakuhin && $last_sakuhin ne "" && $last_sakuhin ne $v->{sid}) || not defined $last_sakuhin;
					print "</p>";	
				print "</div>";
				if($v->{hantyuu} != 700){
				print "<div class='jyou'>";
					print "<div class='jyoukyou' data-jyoutype='$v->{jyoukyou}' data-jyoukyou='$v->{id}'>";
						my $jyoukyou_syori = jyoukyou_settei($v->{jyoukyou}, 0, $v->{jiten}, 609, 609);
						print "<span class='jyoukyou_type_$jyoukyou_type{$jyoukyou_syori} $jyoukyou_class{$jyoukyou_syori}'>";
						print $jyoukyou_syori;
						print "</span>";
					print "</div>";
					print "<span class='jyouhou' data-jyouhou='$v->{id}'>";
					print $v->{part};
					print defined $v->{eternal} && $v->{eternal} == 1 ? "" : "／$v->{whole}";
					print $v->{josuu};
					print "</span>";
				print "</div>";
				}
				print "<div class='bikou${\( sub { return ' ari' if defined $v->{text} && $v->{text} }->() )}'>";
					print "<span class='syurui type_$v->{jyoukyou}'>", Kahifu::Template::dict('KUTIKOMI_TYPE_'.$v->{jyoukyou}), "</span>" if $v->{hantyuu} == 700 && Kahifu::Infra::mobile();
					print $v->{text} if defined $v->{text} && $v->{text};
				print "</div>";
			print "</div>";
			$last_sakuhin = $v->{sid};
			$last_timestamp = $v->{jiten};
		}
		$last_sakuhin = '';
		print !$rireki_row_count ? ongaku_sounyuu($last_sakuhin, $week_limit_upper, $week_limit_lower, \@listen_time, \@listen_info_artist, \@listen_info_album, \@listen_info_track) : ongaku_sounyuu($last_sakuhin, $last_timestamp, $week_limit_lower, \@listen_time, \@listen_info_artist, \@listen_info_album, \@listen_info_track);
		print "<div class='week'>";
		print "</div>";
	print "</div>";
	
	print "<script>
\$(function()
		{
		\$('div.navi > span').click(function()
		  {
			var span = \$(this);
			var text = ${week};
			var new_text = prompt(\"${\(Kahifu::Template::dict('WEEK_NUMBER'))}\", text);
			const params = new URLSearchParams(window.location.search);
			if (new_text != null && Number.isInteger(parseInt(text)) && new_text != text){
				params.set('week', new_text);
				window.location.search = params;
			}
		  });
		});	
	</script>";
}

print <<HTML
<script>
	\$(document).ready(function(){
		function getCookie(name) { 
	  	var cookies = '; ' + document.cookie; 
	  	var splitCookie = cookies.split('; ' + name + '='); 
	  	if (splitCookie.length == 2) return splitCookie.pop();
		}
		
		if(true){
			var current_class = \$('div.commander > div.migi > div.narabikae select:nth-of-type(1) option:selected').attr('class');
			\$('div.commander > div.migi > div.narabikae select:nth-of-type(1)').removeClass();
			\$('div.commander > div.migi > div.narabikae select:nth-of-type(1)').addClass(current_class);
			var current_class_2 = \$('.h_sakuhin select:nth-of-type(2) option:selected').attr('class');
			\$('div.commander > div.migi > div.narabikae select:nth-of-type(2)').removeClass();
			\$('div.commander > div.migi > div.narabikae select:nth-of-type(2)').addClass(current_class_2);
		}
 	});
	
	\$(document).on('change', 'div.commander > div.migi > div.narabikae select', function(){
		\$('#paginate_siborikomi').show();
 	});
 	
 	\$(document).on('change', 'div.commander > div.migi > div.narabikae select:nth-of-type(1)', function(){
		var current_class = \$('div.commander > div.migi > div.narabikae select:nth-of-type(1) option:selected').attr('class');
		\$('div.commander > div.migi > div.narabikae select:nth-of-type(1)').removeClass();
		\$('div.commander > div.migi > div.narabikae select:nth-of-type(1)').addClass(current_class);
	});
  	
	\$(document).on('change', 'div.commander > div.migi > div.narabikae select:nth-of-type(2)', function(){
		var current_class = \$('div.commander > div.migi > div.narabikae select:nth-of-type(2) option:selected').attr('class');
		\$('div.commander > div.migi > div.narabikae select:nth-of-type(2)').removeClass();
		\$('div.commander > div.migi > div.narabikae select:nth-of-type(2)').addClass(current_class);
	});

	\$('.theme').click(function() {
		var sheet = \$(this).attr('class').split(' ')[1];
		var now = new Date();
		var time = now.getTime();
		var expireTime = time + 10000000*36000;
		now.setTime(expireTime);
		document.cookie = 'hyouka_style='+sheet+';expires='+now.toUTCString()+';path=/;SameSite=Strict';	
		console.log("here");		
		\$("div[data-style]").click(function() {
			\$("head link#style").attr("href", \$(this).data("style"));
		});
	});
	
	var category_selected = 0;
	var state_selected = 0;
	var lang_selected = 0;
	
	if(document.cookie.split(";").some((item) => item.trim().startsWith("hyouka_category="))){
		category_selected = document.cookie.split("; ").find((row) => row.startsWith("hyouka_category="))?.split("=")[1];
	}
	
	if(document.cookie.split(";").some((item) => item.trim().startsWith("hyouka_state="))){
		state_selected = document.cookie.split("; ").find((row) => row.startsWith("hyouka_state="))?.split("=")[1];
	}

	if(document.cookie.split(";").some((item) => item.trim().startsWith("hyouka_gengo="))){
		lang_selected = document.cookie.split("; ").find((row) => row.startsWith("hyouka_gengo="))?.split("=")[1];
	}
	
	if(category_selected != 0){
		\$('.hanrei.button div').removeClass('selected_category');
		\$(`.hanrei.button div[data-nokori='\${category_selected}']`).addClass('selected_category');
		\$('div[class^="koumoku type"]:visible').hide();
		\$('div[class^="colle koumoku type"]:visible').hide();
			var onokori = category_selected;
			var onokori_list = onokori.split(',');
			for (let index = 0; index < onokori_list.length; ++index) {
				const element = onokori_list[index];
				\$(`div[class\$="_\${element}"]`).show();
		}
	}
	
	if(state_selected != 0){
		\$('.hanrei.jyoukyou_itirann div').removeClass('selected_category');
		\$(`.hanrei.jyoukyou_itirann div[data-name='\${state_selected}']`).addClass('selected_category');
		\$('.koumoku > .jyou > .jyoukyou:visible').parents('.koumoku').hide().find(`[data-jyoutype='\${state_selected}']`).parents('.koumoku').show();
	}
	
	\$('.hanrei.button div').not('div[class^="hantyuu_all"]').click(function(){
		\$('.hanrei.button div').removeClass('selected_category');
		\$(this).addClass('selected_category');
		\$('div[class^="koumoku type"]:visible').hide();
		\$('div[class^="colle koumoku type"]:visible').hide();
		var onokori = \$(this).attr('data-nokori');
		var onokori_list = onokori.split(',');
		for (let index = 0; index < onokori_list.length; ++index) {
			const element = onokori_list[index];
			\$(`div[class*="_\${element}"]`).show();
		}
		category_selected = onokori;
		if(state_selected != 0){
			\$('.koumoku > .jyou > .jyoukyou:visible').parents('.koumoku').hide().find(`[data-jyoutype='\${state_selected}']`).parents('.koumoku').show();
		}
		
		var now = new Date();
		var time = now.getTime();
		var expireTime = time + 10000000*36000;
		now.setTime(expireTime);
		document.cookie = 'hyouka_category='+category_selected+';expires='+now.toUTCString()+';path=/;SameSite=Strict';		
	});
	
	\$('.hanrei.jyoukyou_itirann div').not('div[class^="jyoukyou all"]').click(function(){
		\$('.hanrei.jyoukyou_itirann div').removeClass('selected_category');
		\$(this).addClass('selected_category');
		var jyou = \$(this).attr('data-name');
		state_selected = jyou;
		if(category_selected != 0){
			\$('div[class^="koumoku type"]:visible').hide();
			\$('div[class^="colle koumoku type"]:visible').hide();
			var onokori = category_selected;
			var onokori_list = onokori.split(',');
			for (let index = 0; index < onokori_list.length; ++index) {
				const element = onokori_list[index];
				\$(`div[class*="_\${element}"]`).show();
			}
		}
		\$('.koumoku > .jyou > .jyoukyou:visible').parents('.koumoku').hide().find(`[data-jyoutype='\${jyou}']`).parents('.koumoku').show();
		
		var now = new Date();
		var time = now.getTime();
		var expireTime = time + 10000000*36000;
		now.setTime(expireTime);
		document.cookie = 'hyouka_state='+state_selected+';expires='+now.toUTCString()+';path=/;SameSite=Strict';	
	});
	
	\$('.hantyuu_all').click(function(){
		\$('.hanrei.button div').removeClass('selected_category');
		\$('div[class^="colle koumoku type"]').show();
		\$('div[class^="koumoku type"]').show();
		category_selected = 0;
		if(state_selected != 0){
			\$('.koumoku > .jyou > .jyoukyou:visible').parents('.koumoku').hide().find(`[data-jyoutype='\${state_selected}']`).parents('.koumoku').show();
		}
		
		var now = new Date();
		var time = now.getTime();
		var expireTime = time + 10000000*36000;
		now.setTime(expireTime);
		document.cookie = 'hyouka_category='+category_selected+';expires='+now.toUTCString()+';path=/;SameSite=Strict';	
	});
	
	\$('.jyoukyou.all').click(function(){
		\$('.hanrei.jyoukyou_itirann div').removeClass('selected_category');
		\$('div[class^="koumoku type"]').show();
		\$('div[class^="colle koumoku type"]').show();
		state_selected = 0;
		if(category_selected != 0){
			\$('div[class^="koumoku type"]:visible').hide();
			\$('div[class^="colle koumoku type"]:visible').hide();
			var onokori = category_selected;
			var onokori_list = onokori.split(',');
			for (let index = 0; index < onokori_list.length; ++index) {
				const element = onokori_list[index];
				\$(`div[class*="_\${element}"]`).show();
			}
		}
		
		var now = new Date();
		var time = now.getTime();
		var expireTime = time + 10000000*36000;
		now.setTime(expireTime);
		document.cookie = 'hyouka_state='+state_selected+';expires='+now.toUTCString()+';path=/;SameSite=Strict';	
	});

	\$('.hanrei .lang').click(function(){
		var gengo = \$(this).attr('data-lang');
		lang_selected = gengo;
		
		var now = new Date();
		var time = now.getTime();
		var expireTime = time + 10000000*36000;
		now.setTime(expireTime);
		document.cookie = 'hyouka_gengo='+lang_selected+';expires='+now.toUTCString()+';path=/;SameSite=Strict';	
	});

\$(function() {
  \$('.jyoukyou').on('click', function() {
	\$(".activity.active").add('#a_' + \$(this).attr('data-jyoukyou')).toggleClass('active');
  });
  \$('.jyouhou').on('click', function() {
	\$(".activity_kousin.active").add('#ak_' + \$(this).attr('data-jyouhou')).toggleClass('active');
  });
  \$('.ten').on('click', function() {
	\$(".ten_kousin.active").add('#tk_' + \$(this).attr('data-ten')).toggleClass('active');
  });
  \$('.midasi').on('click', function() {
	\$(".kansou_kousin.active").add('#kk_' + \$(this).attr('data-kansou')).toggleClass('active');
  });
  \$(document.body).on('click', '.betumei_tuika', function(e){
	var singyou = \$(this).parents('.betumei').find(".betumei_block:first-child").clone();
	\$(singyou).insertBefore(\$(this).siblings('.betumei_block:first-child'));
  });
  \$(document.body).on('click', '.betumei_sakujyo', function(e){
	\$(this).closest('.betumei_block').remove();
  });
});
</script>
HTML
;
# html>exeunt
print Kahifu::Template::html_noti();