#!/usr/bin/perl

use warnings;
use strict;
use Gtk2 '-init';
use Gnome2::Canvas;

use XML::Feed;
use utf8;
use Encode;

my $text;
my $uri = 'http://rss.terra.com.br/0,,EI1,00.xml';
my $posicao;
my $tempo = 20; #maior é mais lento
my $cor = "yellow"; #red, green, blue, black, white, etc..
my $width = 1920; #largura da janela
my $height = 180; #altura da janela
my $altura_texto = 56; #posicao do texto relativa a janela
my $deslocamento = 2; #deslocamento em pixels do texto
my $fontdesc = Gtk2::Pango::FontDescription->from_string("Sans 70");

my $vp = Gtk2::Viewport->new();
my $atualizacao = 0;

my $window; 
$text = Gtk2::Label->new('Notícias');
$vp->modify_bg($text->state,Gtk2::Gdk::Color->new(0*257, 0*257, 125*257));
my ($wi, $he) = $text->get_size_request();
$vp->set_size_request($width, $height);
$vp->add($text);
$text->modify_font($fontdesc);
$text->modify_fg($text->state,Gtk2::Gdk::Color->new(255*255,255*255,0*255));
$vp->modify_bg($text->state,Gtk2::Gdk::Color->new(0*000, 0*000, 000*000));

$window = Gtk2::Window->new();
$window->set_decorated(0);
$window->set_default_size($width,$height);
$window->add($vp);
$window->move(0,915);
$window->show_all();

my $timer = Glib::Timeout->add($tempo, \&timer);
$posicao = $vp->get_hadjustment->lower();

Gtk2->main();

sub timer {

    sleep 1 if $posicao == $vp->get_hadjustment->lower();
    $posicao += $deslocamento;
    $posicao = $vp->get_hadjustment->lower() if $posicao > $vp->get_hadjustment->upper();

    $vp->get_hadjustment->set_value($posicao);
    if (int(time() - $atualizacao) > (60 * 10)) {
       warn ".";
       my $ts ;
       my $feed = XML::Feed->parse(URI->new($uri)) or die XML::Feed->errstr;
       for my $entry ($feed->entries) {
          $ts .= '       >> '.$entry->title;
       }
       $ts =~ tr[\x0a\x0d][  ]d; #strip newlines
       if ($text->get_text() ne $ts) {
          warn $text->get_text();
          $text->set_text($ts);
          ($wi, $he) = $text->get_size_request();
          $vp->set_size_request($width, $height);
          warn $text->get_text();
          $posicao = $vp->get_hadjustment->lower();
       }
       $atualizacao = time();
    }
    return 1;
}
