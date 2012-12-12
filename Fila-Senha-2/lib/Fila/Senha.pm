package Fila::Senha;
use utf8;
use 5.010;
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
use EV;
use EV::Glib;
use Gtk2::GladeXML;
use Gtk2 '-init';

use Catalyst::Runtime '5.70';
use Catalyst qw/-Debug ConfigLoader Static::Simple/;
use Net::XMPP2::Connection;

our $VERSION = '0.01';

__PACKAGE__->setup;

our $porta_impressora;
our $porta_emissor;
our $categorias;

{
	my $portas = __PACKAGE__->config->{portas};
	die 'Porta da impressora nao configurada' unless
		$porta_impressora = $portas->{impressora};

	die 'Porta do emissor nao configurada' unless
		$porta_emissor = $portas->{emissor};

	$categorias = __PACKAGE__->config->{categorias}
	or die 'Categorias nao configuradas.';

}

$::gladexml = undef;
$::window = undef;
$::chamar = undef;
@::categorias_nomes = ();
@::categorias_ids = ();

{
	$::gladexml = Gtk2::GladeXML->new(
			'/usr/share/fila/Fila-Senha/script/Fila-Senha.glade'
			) or die 'died: '.$!;
	$::gladexml->signal_autoconnect_from_package(__PACKAGE__);
	$::window = $::gladexml->get_widget('window1');
	$::header = $::gladexml->get_widget('header');
	$::header->modify_font(Gtk2::Pango::FontDescription->from_string("Arial Bold 20"));
	$::header->set_label('AGUARDE');
	$::footer = $::gladexml->get_widget('footer');
	$::footer->modify_font(Gtk2::Pango::FontDescription->from_string("Arial Bold 20"));
	$::footer->set_label('...');
	Gtk2::Window::fullscreen($::window);
	$::window->set_opacity(0.8);
	$::window->show;
	my $i = 0;
}

sub atualizar_categorias {
	my $i = 0;
	my @button;
	my $counter;
	unless ($::connection && $::connection->is_connected) {
		warn 'no connection';
	}
	if (scalar @::categorias_nomes) {
		$::aguarde = 0;
		$::header->set_label('TOQUE SOBRE O HORÁRIO MAIS PRÓXIMO DO SEU AGENDAMENTO');
		$::footer->set_label('AMA Especialidades Jardim Pirajussara');
	} else {
		$::header->set_label('AGUARDE ');
		$::footer->set_label('...');
	}
	foreach my $h ('07', '08', '09', '10', '11','13', '14', '15', '16', '17') {
		foreach my $m ('00', '15', '30', '45') {
			my $button = $::gladexml->get_widget($h.':'.$m);
			$button[$i]->child->modify_font(Gtk2::Pango::FontDescription->from_string("Arial Bold 20"));
			my $hor = localtime()[2];
			my $min = localtime()[1] + 2;
			if (($hor > $h) || ($min > $m) { 
				$button->hide;
			} else ($min > m) {
				$button->show;
			}
		}
	}
	return 1;
}

sub on_button_clicked {
	my $self = shift;
	return () unless $::connection->is_connected;
	my $o = $self->get_name;
	if ($o =~ s/(\d\d)\:(\d\d)/) {
		Fila::Senha->model('Emissor')->bloquear;
		$::chamar = $::categorias_ids[0];
		&atualizar_categorias if $::connection->is_connected;
		$self->leave;
	}
}

sub imprimir_senha {
	if ($::connection->is_connected && defined $::chamar) {
		my $dados = Fila::Senha->model('SOAP::Senha')->solicitar_senha
			({ atendimento => { id_categoria => $::chamar } });
		if ($dados->{Fault}) {
			warn 'Erro ao pedir senha. '.$dados->{Fault}{faultstring};
		} else {
			warn 'Imprimir senha';
			$::footer->set_label($dados->{atendimento}{senha});
			Fila::Senha->model('Impressora')->imprimir_senha($dados);
			$::chamar = undef;
			$::senha_timer = EV::timer (3, 0, \&limpar_senha);
		}
	}
}

sub limpar_senha {
	if ($::connection->is_connected) {
		my $dados_local = Fila::Senha->model('SOAP::Senha')->dados_local({ local => {} });
		if ($dados_local->{Fault} && $dados_local->{Fault}{faultstring} =~ /Permissao Negada/) {
			Fila::Senha->model('Emissor')->bloquear;
		} else {
			Fila::Senha->model('Emissor')->abrir;
		}
		&atualizar_categorias;
	} else {
		Fila::Senha->model('Emissor')->bloquear;
	}
}

# Inicializar uma conexão principal de controle que ira fazer a
# inicializacao

$::connection = Net::XMPP2::Connection->new
(%{Fila::Senha->config->{'Engine::XMPP2'}},
 resource => 'Main Connection');

$::connection->reg_cb
(bind_error => sub {
 warn 'Error binding to resource'.localtime();
 EV::unloop(EV::UNLOOP_ALL);
 },

 iq_auth_error => sub {
 warn 'Authentication error '.localtime();
 EV::unloop(EV::UNLOOP_ALL);
 },

 sasl_error => sub {
 warn 'Authentication error '.localtime();
 EV::unloop(EV::UNLOOP_ALL);
 },

 disconnect => sub {
 warn 'disconnected '.localtime();
 $::connection->connect;
 },

 stream_error => sub {
	 warn 'Connection error.';
	 EV::unloop(EV::UNLOOP_ALL);
 },

 stream_ready => sub {
	 $::connection->send_presence('available', sub {});

	 Fila::Senha->model('SOAP')->transport->connection($::connection);
	 Fila::Senha->model('SOAP')->transport->addrs(['motor@gestao.fila.vhost/ws/gestao/senha']);

	 our $dados_local = Fila::Senha->model('SOAP::Senha')
		 ->dados_local({ local => {} });

	 if ($dados_local->{Fault} &&
			 $dados_local->{Fault}{faultstring} =~ /Permissao Negada/) {
		 warn 'Local está fechado. Vai esperar uma notificacao.';
		 Fila::Senha->model('Emissor')->bloquear;
	 } elsif ($dados_local->{Fault}) {
		 warn 'Erro ao obter os dados do local: '.$dados_local->{Fault}{faultstring};
		 EV::unloop(EV::UNLOOP_ALL());
	 } else {
		 warn 'Abrindo para senhas';
		 Fila::Senha->model('Emissor')->abrir;
	 }
	 $::imprimir_senha = EV::timer (1, 1, \&imprimir_senha);
	 $::atualizar_categorias = EV::timer(1, 0, \&atualizar_categorias);
	 eval {
		 Fila::Senha->run();
	 };
	 if ($@) {
		 warn 'Error running application: '.$@;
		 EV::unloop(EV::UNLOOP_ALL);
	 }
 });


unless ($::connection->connect) {
	EV::unloop(EV::UNLOOP_ALL);
	die 'Cannot connect to server';
} else {
	EV::loop;
}

1;

__END__

=head1 NAME

Fila::Senha - Aplicação de comunicação com o emissor de senha e a impressora.

=head1 SYNOPSIS

# dentro do diretorio Fila-Senha
./script/fila_senha_app.pl

=head1 DESCRIPTION

Essa aplicação é responsável por comunicar-se tanto com o dispositivo
emissor de senha que notifica quando algum dos seus botões são
pressionados, quanto com a impressora que recebe o texto para ser
impresso com os dados da senha.

=cut

