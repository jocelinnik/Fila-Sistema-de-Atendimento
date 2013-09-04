package Fila::Servico::DB::TipoEstadoAtendimento;

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

use base qw(DBIx::Class);

__PACKAGE__->load_components(qw(InflateColumn::DateTime PK::Auto Core));
__PACKAGE__->table('tipo_estado_atendimento');
__PACKAGE__->add_columns(
  id_estado => {
    data_type         => 'integer',
    is_auto_increment => 1,
  },
  nome => { data_type => 'varchar', },
);
__PACKAGE__->set_primary_key(qw(id_estado));
__PACKAGE__->has_many(
  'atendimentos',
  'Fila::Servico::DB::EstadoAtendimento',
  { 'foreign.id_estado' => 'self.id_estado' }
);

1;

__END__

=head1 NAME

TipoEstadoAtendimento - Valores possíveis para o estado de um atendimento

=head1 DESCRIPTION

Esta tabela mantém a lista dos valores possíveis para o estado de um
atendimento. Apesar de essa configuração estar em um banco de dados,
existe um conjunto de valores que são obrigatórios para o bom
funcionamento do sistema.

=cut

