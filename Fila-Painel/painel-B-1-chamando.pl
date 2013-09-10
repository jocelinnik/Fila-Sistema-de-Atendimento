#!/usr/bin/perl
# Copyright 2008, 2009 - Oktiva Comércio e Serviços de Informática Ltda.
#
# Este arquivo é parte do programa FILA - Sistema de Atendimento
#
# O FILA é um software livre; você pode redistribui-lo e/ou modifica-lo
# dentro dos termos da Licença Pública Geral GNU como publicada pela
# Fundação do Software Livre (FSF); na versão 2 da Licença.
#
# Este programa é distribuido na esperança que possa ser util, mas SEM
# NENHUMA GARANTIA; sem uma garantia implicita de ADEQUAÇÂO a qualquer
# MERCADO ou APLICAÇÃO EM PARTICULAR. Veja a Licença Pública Geral GNU
# para maiores detalhes.
#
# Você deve ter recebido uma cópia da Licença Pública Geral GNU, sob o
# título "LICENCA.txt", junto com este programa, se não, escreva para a
# Fundação do Software Livre(FSF) Inc., 51 Franklin St, Fifth Floor,
use strict;
use warnings;
use utf8;
use Gtk2 -init;
use Gtk2::GladeXML;
use Gnome2::Canvas;
use Data::Dumper;
use POSIX qw(strftime ceil floor);
use Weather::Google;
use XML::Feed;

my $uri = 'http://rss.terra.com.br/0,,EI1,00.xml';

#my $uri = 'http://portalsaude.saude.gov.br/portalsaude/feeds/rss.cfm?area=2&codModuloArea=162';
my $chamada = 0;

# If you plan on using locations with non-ASCII characters
use encoding 'utf8';

$| = 1;
use constant {
  INPUT_FILE          => '/srv/lenny/tmp/senhas_chamando.csv',
  TEMPO_ROTACAO       => 5,
  TEMPO_RECHAMADA     => 90,
  TEMPO_ULTIMAS       => 8,
  TEMPO_TIRAR_ULTIMAS => 360,
};

my $gladexml = Gtk2::GladeXML->new('painel-B-1-chamando.glade');

my ( $window, $lblsenha, $lblultima, $label_time, $label_clima,
  $viewport_news, $label_news )
    = map { $gladexml->get_widget($_) }
    qw(window1 label_chamando label_ultimas label_time label_clima viewport_news label_news);

our @chamar_atencao;
our @rotacao;
our @ultimas;
our $status = 'iniciando';
our $error;
our $pagina_ultimas  = 0;
our $pagina_atencao  = 0;
our $pagina_rotacao  = 0;
our $counter_rotacao = 0;
our @voice;

print localtime() . "// Painel iniciado \n";

setup_widgets();

our $to_atencao;
our $to_rotacao;
our $to_check;

&atualizar_relogio;

#&atualizar_clima;
&atualizar_noticias;
&check_input_file;

Glib::Timeout->add( TEMPO_ULTIMAS * 1000, \&cycle_ultimas );
Glib::Timeout->add( 10 * 1000,            \&atualizar_relogio );

#Glib::Timeout->add(10 * 60 * 1000, \&atualizar_clima);
Glib::Timeout->add( 1000 / 30, \&atualizar_noticias );

my $posicao = $viewport_news->get_hadjustment->lower();
my $atualizacao;

Gtk2->main();

sub atualizar_noticias {
  $posicao += 6;
  $posicao = $viewport_news->get_hadjustment->lower()
      if $posicao > $viewport_news->get_hadjustment->upper();

  $viewport_news->get_hadjustment->set_value($posicao);

  if ( int( time() - $atualizacao ) > ( 60 * 10 ) ) {
    my $ts;
    my $feed = XML::Feed->parse( URI->new($uri) ) or warn XML::Feed->errstr;
    for my $entry ( $feed->entries ) {
      $ts .= ' → ' . $entry->title . '   ';
    }
    $ts =~ tr[\x0a\x0d][  ]d;    #strip newlines
    $ts =~ s/\<br\>//g;
    if ( $label_news->get_text() ne $ts ) {
      $label_news->set_text($ts);
      my ( $wi, $he ) = $label_news->get_size_request();
      $viewport_news->set_size_request( 1920, 180 );
      $posicao = $viewport_news->get_hadjustment->lower();
    }
    $atualizacao = time();
  }
  return 1;
}

sub atualizar_relogio {
  warn strftime( "%H:%M", localtime(time) );
  $label_time->set_label( strftime( "%d/%m", localtime(time) ) . "\n"
        . strftime( "%H:%M", localtime(time) ) );
  return 1;
}

sub atualizar_clima {
  my $gw = new Weather::Google;
  $gw->language('pt-BR');
  $gw->encoding('utf8');
  $gw->city('São Paulo, SP');
  my $current;
  $current = $gw->current;
  foreach my $k ( keys %{$current} ) {
    warn $k . ": " . $current->{$k} . "\n";
  }
  $label_clima->set_label( "Temperatura: "
        . $gw->temp_c . '°C ('
        . $gw->today('low') . '/'
        . $gw->today('high') . '°C)' . "\n"
        . $gw->condition . " — "
        . $gw->humidity );
  return 1;
}

sub check_input_file {
  return if @chamar_atencao;
  warn "check_input_file";
  open my $file, '<', INPUT_FILE or do {
    warn 'Não conseguiu abrir arquivo ' . $!;
    Glib::Timeout->add( 3000, \&check_input_file );
    return ();
  };
  my $time    = time;
  my @arquivo = <$file>;

  @arquivo = grep {/\.*,\.*/} @arquivo;

  @arquivo = map { chomp; [ split( /,/, $_ ), $time ] } @arquivo;

  close($file);

  #
  # Mesma senha, guichê diferente
  #

  my @new =
      grep {
    my $a = $_;
    !( grep { $a->[0] eq $_->[0] && $a->[1] eq $_->[1] } @rotacao )
      } @arquivo;

  my @old =
      grep {
    my $a = $_;
    !( grep { $a->[0] eq $_->[0] && $a->[1] eq $_->[1] } @arquivo )
      } @rotacao;

  for ( my $i = 0; $i < @new; $i++ ) {
    unshift( @chamar_atencao, [ $new[$i][0], $new[$i][1], $time ] );
    unshift( @rotacao,        [ $new[$i][0], $new[$i][1], $time ] );
  }

  for ( my $j = 0; $j < @old; $j++ ) {
    unshift( @ultimas, [ $old[$j][0], $old[$j][1], $time ] );
  }

  my @rot;
  for ( my $k = 0; $k < @rotacao; $k++ ) {
    foreach my $a (@arquivo) {
      if ( $a->[0] eq $rotacao[$k]->[0] && $a->[1] eq $rotacao[$k]->[1] ) {
        if ( $time - $rotacao[$k][2] > TEMPO_RECHAMADA ) {
          push( @rot, [ $rotacao[$k][0], $rotacao[$k][1], $time ] );
          unshift( @chamar_atencao,
            [ $rotacao[$k][0], $rotacao[$k][1], $time ] );
        }
        else {
          push( @rot, $rotacao[$k] );
        }
      }
    }
  }
  @rotacao = @rot;
  my @ult;
  for ( my $l = 0; $l < @ultimas; $l++ ) {
    unless ( $time - $ultimas[$l][2] > TEMPO_TIRAR_ULTIMAS ) {
      push( @ult, $ultimas[$l] );
    }
  }
  @ultimas = @ult;
  if ( scalar(@new) ) {
    Glib::Source->remove($to_rotacao) if $to_rotacao;
    $to_atencao = Glib::Timeout->add( 1000, \&cycle_chamando );
  }
  else {
    Glib::Timeout->add( 3000, \&check_input_file );
  }
  return ();
}

sub alert {
  my @sons = @_;
  my $sons;
  foreach my $som (@sons) {
    $sons .= " " . $som . ".wav ";
  }
  my $str = '/usr/bin/mplayer Fila_Painel_Alert.ogg ' . $sons . ' & ';
  warn $str;
  system($str);
  return ();
}

sub cycle_chamando {
  warn "Chamando";
  foreach my $ch (@chamar_atencao) {
    print 'Chamar atencao: ' . $ch->[0] . ' ' . $ch->[1] . "\t";
  }
  print "\n";
  foreach my $rt (@rotacao) {
    print 'Rotacao: ' . $rt->[0] . ' ' . $rt->[1] . "\t";
  }
  print "\n";
  my @now;
  Glib::Source->remove($to_rotacao) if $to_rotacao;
  $pagina_atencao = 0 unless $to_atencao;
  if (@chamar_atencao) {
    warn "chamar_atencao";
    my $paginas = ceil( @chamar_atencao / 2 );
    if ($paginas) {
      my $porpagina = ceil( @chamar_atencao / $paginas );

      for ( my $i = 0; $i < $porpagina; $i++ ) {
        push @now, shift @chamar_atencao if @chamar_atencao;
      }
      my $str;
      my @sons;
      foreach my $chamada (@now) {
        $str .= $chamada->[0] . " " . $chamada->[1] . "\n";
        push(
          @sons,
          (
            'SENHA',  split( //, $chamada->[0] ),
            'GUICHE', split( //, $chamada->[1] )
          )
        );
      }

      $lblsenha->set_label($str);
      $to_atencao = undef;
      if (@chamar_atencao) {
        $to_atencao =
            Glib::Timeout->add( TEMPO_ROTACAO * 1000, \&cycle_chamando );
      }
      else {
        $to_rotacao =
            Glib::Timeout->add( TEMPO_ROTACAO * 1000, \&cycle_chamando );
      }
      &alert(@sons);
    }
  }
  else {
    warn "rotacao";
    my $paginas = ceil( @rotacao / 2 );
    if ($paginas) {
      my $porpagina = ceil( @rotacao / $paginas );
      if ( $pagina_rotacao < $paginas ) {
        my $inicio = $porpagina * $pagina_rotacao++;
        my $fim    = $inicio + $porpagina;
        my $str    = '';
        for ( my $i = $inicio; $i < $fim; $i++ ) {
          $str .= $rotacao[$i][0] . " " . $rotacao[$i][1] . "\n"
              if exists $rotacao[$i];
        }
        $lblsenha->set_label($str);
      }
      else {
        $pagina_rotacao = 0;
      }
    }
    else {
      $lblsenha->set_label('');
    }
    Glib::Source->remove($to_atencao) if $to_atencao;
    Glib::Source->remove($to_rotacao) if $to_rotacao;
    $to_rotacao =
        Glib::Timeout->add( TEMPO_ROTACAO * 1000, \&cycle_chamando );
  }
  Glib::Source->remove($to_check) if $to_check;
  $to_check = Glib::Timeout->add( 3000, \&check_input_file );
  return undef;
}

sub cycle_ultimas {
  warn "cycle_ultimas";

  $lblultima->set_label('');

  my $paginas = ceil( @ultimas / 4 );

  return 1 unless $paginas;

  warn " Updating últimas";

  my $porpagina = ceil( @ultimas / $paginas );

  $pagina_ultimas = 0 if $pagina_ultimas >= $paginas;

  my $inicio = $porpagina * $pagina_ultimas++;

  my $fim = $inicio + $porpagina - 1;
  my $str;
  my @esta = @ultimas[ $inicio .. $fim ];
  foreach my $u (@esta) {
    $str .= $u->[0] . ' ' . $u->[1] . "\n";
  }
  print " Últimas:\n" . $str . "\n";
  $lblultima->set_label($str);
  return 1;
}

sub setup_widgets {
  $window->signal_connect( 'destroy', sub { Gtk2->main_quit } );
  $window->set_decorated(0);
  $window->move( 1025, 0 );
  $window->modify_bg( $window->state, Gtk2::Gdk::Color->parse("#000000") );
  Gtk2::Window::fullscreen($window);
  $lblsenha->modify_font(
    Gtk2::Pango::FontDescription->from_string("Courier Bold 100") );
  $lblsenha->modify_fg( $lblsenha->state, Gtk2::Gdk::Color->parse("Yellow") );
  $lblultima->modify_font(
    Gtk2::Pango::FontDescription->from_string("Courier Bold 100") );
  $lblultima->modify_fg( $lblultima->state,
    Gtk2::Gdk::Color->parse("Light Blue") );

  $label_clima->modify_font(
    Gtk2::Pango::FontDescription->from_string("Tahoma 50") );
  $label_clima->modify_fg( $label_clima->state,
    Gtk2::Gdk::Color->parse("Light Blue") );
  $label_time->modify_font(
    Gtk2::Pango::FontDescription->from_string("Tahoma 50") );
  $label_time->modify_fg( $label_time->state,
    Gtk2::Gdk::Color->parse("Light Yellow") );
  $label_news->modify_font(
    Gtk2::Pango::FontDescription->from_string("Tahoma 100") );
  $label_news->modify_fg( $label_news->state,
    Gtk2::Gdk::Color->parse("Light Green") );
  $viewport_news->modify_bg( $label_news->state,
    Gtk2::Gdk::Color->new( 0 * 000, 0 * 000, 000 * 000 ) );
  $window->show_all();
}
