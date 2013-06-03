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
use lib 'lib';
use SQL::Translator;

my $t = SQL::Translator->new
  (
   show_warnings       => 1,
   add_drop_table      => 1,
   quote_table_names   => 1,
   quote_field_names   => 1,
   validate            => 1,
  );
$t->parser_args
  (
   'DBIx::Schema' => 'Fila::Agendamento::DB',
  );
my $r = $t->translate
  (
   from => 'SQL::Translator::Parser::DBIx::Class',
   to => 'PostgreSQL',
  ) or die $t->error;
print $r;

print <<SQL;
DROP TABLE intervalos;

CREATE VIEW intervalos AS
 SELECT inicio, inicio + interval '30 minutes' AS fim
 FROM (
    SELECT (DATE_TRUNC('day',NOW()) + dias * INTERVAL '1 day' + hora * INTERVAL '1 hour' + atend * INTERVAL '30 minutes') AS inicio
    FROM
    GENERATE_SERIES(0,29) dias,
    GENERATE_SERIES(0,23) hora,
    GENERATE_SERIES(0, 1) atend
    ORDER BY inicio
 ) AS t(inicio)
 WHERE t.inicio >= NOW() + interval '4 hour';

INSERT INTO local VALUES (1, '2008-01-01 00:00:00+0000', 'Infinity', 'Local de Teste');
INSERT INTO expediente VALUES (1, 1, 1, 8, 20);
INSERT INTO expediente VALUES (2, 1, 2, 8, 20);
INSERT INTO expediente VALUES (3, 1, 3, 8, 20);
INSERT INTO expediente VALUES (4, 1, 4, 8, 20);
INSERT INTO expediente VALUES (5, 1, 5, 8, 20);


SQL
