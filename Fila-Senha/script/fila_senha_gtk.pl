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

$ENV{CATALYST_ENGINE} = 'XMPP2';

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use FindBin;
use lib "$FindBin::Bin/../lib";

use EV;
use EV::Glib;
use AnyEvent;
use Net::XMPP2::Connection;
use Catalyst::Engine::XMPP2;
{
    no warnings;
    *Catalyst::Engine::XMPP2::loop = *EV::loop;
}

my $debug             = 0;
my $help              = 0;

my @argv = @ARGV;

GetOptions(
    'debug|d'             => \$debug,
    'help|?'              => \$help,
);

pod2usage(1) if $help;

if ( $debug ) {
    $ENV{CATALYST_DEBUG} = 1;
}



use EV;
use EV::Glib;
use Gtk2::GladeXML;
use Gtk2 '-init';

$::gladexml = undef;
$::window = undef;
$::chamar = undef;
@::categorias_nomes = ();
@::categorias_ids = ();

&create_window;

require Fila::Senha;
Fila::Senha->run();

sub create_window {
 $::gladexml = Gtk2::GladeXML->new(
  '/usr/share/fila/Fila-Senha/script/Fila-Senha.glade'
 ) or die 'died: '.$!;
 $::gladexml->signal_autoconnect_from_package(__PACKAGE__);
 $::window = $::gladexml->get_widget('window1');
 Gtk2::Window::fullscreen($::window);
 &atualizar_categorias;
 $::window->show;
 Glib::Timeout->add(1000, \&atualizar_categorias);
}

sub atualizar_categorias {
   my $i = 0;
   my @button;
   my $button;
   while ($i < 10) {
    $button = $i + 1;
    $button[$i] = $::gladexml->get_widget('button'.$button);
    if (defined $::chamar) {
      my $dados = Fila::Senha->model('SOAP::Senha')->solicitar_senha
        ({ atendimento => { id_categoria => $::chamar } });
      if ($dados->{Fault}) {
        warn 'Erro ao pedir senha. '.$dados->{Fault}{faultstring};
      } else {
        warn 'Imprimir senha';
        Fila::Senha->model('Impressora')->imprimir_senha($dados);
        $::chamar = undef;
      }
    }
    if (defined $::categorias_nomes[$i]) {
     $button[$i]->set_label($::categorias_nomes[$i]);
     $button[$i]->show;
    } else {
     $button[$i]->hide;
    }
   } continue {
    $i++;
   }
   return 1;
}

sub on_button_clicked {
 my $self = shift;
 my $o = $self->get_name;
 $o =~ s/button//gi;
 $::chamar = $::categorias_ids[$o-1];
}


1;
