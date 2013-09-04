use utf8;

package Fila::WebApp::Model::Impressora;

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
use IO::Handle;
use utf8;
use DateTime::Format::XSD;
use Encode;
use IO::Handle;
use POSIX qw(:termios_h);
use base 'Catalyst::Model';

__PACKAGE__->mk_accessors('fh');

sub imprimir_senha {
  my ( $self, $dados ) = @_;
  return ();
  $self->_check_fh;

  my $date =
      DateTime::Format::XSD->parse_datetime( $dados->{atendimento}{vt_ini} );
  $date->set_time_zone('local');
  my $san = $dados->{atendimento}{id_atendimento};
  $san = substr( $san, -9 );
  my $a = encode( 'CP850',
          "\eH\e\x0f" . "\eA"
        . "Organização\n" . "\eB"
        . "Departamento" . "\n\n"
        . "\eA\eC"
        . "        "
        . $dados->{atendimento}{senha}
        . "\eB\eD" . "\n\n"
        . "Atendimento:\n" . "\eA"
        . sprintf( '%09s', $san ) . " -- "
        . $date->strftime('%F') . "\n" . "\eB"
        . "   http://www.website.com.br\n"
        . "      Cidade - UF \n\n" );

  use bytes;
  warn encode( 'utf8', $a );
  syswrite $self->fh, $a
      . encode( 'CP850', " - - - - -  2ª VIA DA SENHA  - - - - - \n\n\x11" );

}

sub _check_fh {
  my $self = shift;

  return if $self->fh;

  #    if ($Fila::WebApp::porta_impressora eq 'emulate') {
  #	$self->fh(\*STDOUT);
  #	return;
  #    }

  open my $fh, '>', '/dev/lp0' or die $!;

  $fh->blocking(1);

#my $term = POSIX::Termios->new;
#$term->getattr(fileno($fh)) or die $!;
#$term->setospeed(&POSIX::B9600);
#$term->setispeed(&POSIX::B9600);
#$term->setiflag((&POSIX::IXON | &POSIX::IXOFF | &POSIX::IGNPAR)&(~(&POSIX::IGNBRK | &POSIX::BRKINT)));
#$term->setlflag($term->getlflag & ~&POSIX::ECHO);
#$term->setcflag($term->getcflag | &POSIX::CSIZE | &POSIX::CS7);
#$term->setattr(fileno($fh), &POSIX::TCSANOW) or die $!;

  $self->fh($fh);
}

1;

__END__

=head1 NAME

Fila::WebApp::Model::Impressora - Imprime a Senha

=head1 DESCRIPTION

Este é o Módulo responsável por imprimir a senha para a impressora
térmica. Esse módulo pressupõe o formato de impressão da Impressora
Térmica Daruma DR600.

É importante notar que esse módulo utiliza escrita síncrona na
impressora. Para garantir que não aconteça um pedido de senha no meio
da impressão de uma outra senha. O sistema estará bloqueado e só
processará o pedido de uma nova senha no momento em que a impressora
terminar de receber a informação.

É preciso entender que isso não necessariamente se coloca como um
problema porque a impressora costuma ter um buffer que aguenta uma
quantidade sificiente de informação para evitar qualquer travamento.

=cut

