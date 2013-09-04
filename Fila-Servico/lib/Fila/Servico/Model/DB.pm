package Fila::Servico::Model::DB;

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
use base 'Catalyst::Model::DBIC::Schema';

__PACKAGE__->config(
  schema_class => 'Fila::Servico::DB',
  connect_info => [
    'dbi:Pg:host=127.0.0.1;database=fila;', 'fila',
    'senha', { pg_enable_utf8 => 1, },
  ]
);
1;

__END__

=head1 NAME

DB - Configura o acesso ao DBIx::Class

=head1 DESCRIPTION

Seguindo a configuração no arquivo fila_servico.yml, define os meios
de acesso para o banco de dados utilizando o DBIx::Class.

=cut

