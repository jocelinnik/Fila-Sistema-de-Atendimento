package Fila::WebApp::Model::SOAP;

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
use XML::CompileX::Transport::SOAPXMPP;
use base 'Catalyst::Model::SOAP';

__PACKAGE__->config->{transport} = XML::CompileX::Transport::SOAPXMPP->new();

__PACKAGE__->register_wsdl(
  {
    wsdl   => Fila::WebApp->path_to('/schemas/FilaServico.wsdl'),
    schema => Fila::WebApp->path_to('/schemas/fila-servico.xsd')
  },
  {
    GestaoLocal     => 'Gestao::Local',
    GestaoGuiche    => 'Gestao::Guiche',
    GestaoAtendente => 'Gestao::Atendente',
    GestaoSenha     => 'Gestao::Senha'
  }
);

1;

__END__

=head1 NAME

SOAP - Acesso ao Fila-Servico

=head1 DESCRIPTION

Esse é o módulo responsável por prover acesso à aplicação
Fila::Serviço.

=cut

