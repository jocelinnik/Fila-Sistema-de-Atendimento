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
use DateTime;
use DateTime::Format::XSD;
use Catalyst::Runtime '5.70';
use Catalyst qw/ConfigLoader/;
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

$::gladexml         = undef;
$::window           = undef;
$::chamar           = undef;
@::categorias_nomes = ();
@::categorias_ids   = ();

{
    $::gladexml =
      Gtk2::GladeXML->new('/usr/share/fila/Fila-Senha/script/Fila-Senha.glade')
      or die 'died: ' . $!;
    $::gladexml->signal_autoconnect_from_package(__PACKAGE__);
    $::window = $::gladexml->get_widget('window1');
    $::window->resize( 1024, 768 );

    my $back_pixbuf = Gtk2::Gdk::Pixbuf->new_from_file(
        '/usr/share/fila/Fila-Senha/Fila-Senha-Emissor-Gtk2-Cejam.png');
    my ( $pixmap, $mask ) = $back_pixbuf->render_pixmap_and_mask(255);
    my $style = $::window->get_style();
    $style = $style->copy();
    $style->bg_pixmap( "normal", $pixmap );
    $::window->set_style($style);

    $::window->modify_bg( $::window->state,
        Gtk2::Gdk::Color->parse("#000000") );
    $::header  = $::gladexml->get_widget('header');
    $::horario = $::gladexml->get_widget('horario');

    $::hora   = $::gladexml->get_widget('hora')   or warn $!;
    $::minuto = $::gladexml->get_widget('minuto') or warn $!;

    if ($::hora) {
        $::hora->modify_font(
            Gtk2::Pango::FontDescription->from_string("Arial 50") );
        $::hora->modify_fg( $::header->state,
            Gtk2::Gdk::Color->parse("#FFFFFF") );
        $::hora->modify_bg( $::header->state,
            Gtk2::Gdk::Color->parse("#000000") );
    }
    if ($::minuto) {
        $::minuto->modify_font(
            Gtk2::Pango::FontDescription->from_string("Arial 50") );
        $::minuto->modify_fg( $::header->state,
            Gtk2::Gdk::Color->parse("#FFFFFF") );
        $::minuto->modify_bg( $::header->state,
            Gtk2::Gdk::Color->parse("#000000") );
    }

    $::horario->modify_font(
        Gtk2::Pango::FontDescription->from_string("Arial 20") );
    $::horario->modify_fg( $::header->state,
        Gtk2::Gdk::Color->parse("#FFFFFF") );
    $::horario->modify_bg( $::header->state,
        Gtk2::Gdk::Color->parse("#000000") );

    $::header->modify_font(
        Gtk2::Pango::FontDescription->from_string("Arial 20") );
    $::header->modify_fg( $::header->state,
        Gtk2::Gdk::Color->parse("#FFFFFF") );
    $::header->modify_bg( $::header->state,
        Gtk2::Gdk::Color->parse("#000000") );
    $::header->set_label('AGUARDE');
    $::footer = $::gladexml->get_widget('footer');
    $::footer->modify_font(
        Gtk2::Pango::FontDescription->from_string("Arial 20") );
    $::footer->modify_fg( $::footer->state,
        Gtk2::Gdk::Color->parse("#FFFFFF") );
    $::footer->modify_bg( $::footer->state,
        Gtk2::Gdk::Color->parse("#000000") );
    $::header->set_label('AGUARDE');
    $::footer->set_label('...');
    Gtk2::Window::fullscreen($::window);
    $::window->fullscreen;
    $::window->set_opacity(0.9);
    $::window->show_all;
}

sub atualizar_categorias {
    my $i = 0;
    my @button;
    my $counter;
    unless ( $::connection && $::connection->is_connected ) {
        warn 'no connection';
    }
    if ( scalar @::categorias_nomes ) {
        $::header->set_label("AGUARDE ORIENTAÇÃO");
        $::footer->set_label('AMA Especialidades Vera Cruz');
    }
    else {
        warn "Bloqueado";
        $::header->set_label('AGUARDE ');
        $::footer->set_label('...');
        $::atualizar_categorias = EV::timer( 10, 0, \&atualizar_categorias );
    }
    while ( $i < 15 ) {
        my $button = $i + 1;
        $button[$i] = $::gladexml->get_widget( 'button' . $button );
        if ( defined $::categorias_nomes[$i] ) {
            $button[$i]->set_label( $::categorias_nomes[$i] );
            $button[$i]->child->modify_font(
                Gtk2::Pango::FontDescription->from_string("Arial Bold 20") );
            $button[$i]->show;
        }
        else {
            $button[$i]->hide;
        }
    }
    continue {
        $i++;
    }
    return 1;
}

sub on_button_clicked {
    my $self = shift;
    return () unless $::connection->is_connected;
    my $o = $self->get_name;
    $o =~ s/button//gi;
    Fila::Senha->model('Emissor')->bloquear;
    $::chamar = $::categorias_ids[ $o - 1 ];
    &atualizar_categorias if $::connection->is_connected;
    $self->leave;
}

sub imprimir_senha {
    if ( $::connection->is_connected && defined $::chamar ) {

        my $hora   = sprintf( '%02s', $::hora->get_value_as_int );
        my $minuto = sprintf( '%02s', $::minuto->get_value_as_int );

        my $dt = DateTime->now(
                time_zone => 'local',

	);
	$dt->set(hour      => $hora,
                minute       => $minuto,

        );

        warn DateTime::Format::XSD->format_datetime($dt);

        my $dados = Fila::Senha->model('SOAP::Senha')->solicitar_senha(
            {
                atendimento => {
                    id_categoria => $::chamar,
                    vt_ini       => DateTime::Format::XSD->format_datetime($dt),
                }
            }
        );
        if ( $dados->{Fault} ) {
            warn 'Erro ao pedir senha. ' . $dados->{Fault}{faultstring};
            &limpar_senha;
            $::chamar = undef;
        }
        else {
            warn 'Imprimir senha';
            $::footer->set_label( $dados->{atendimento}{senha} );
            Fila::Senha->model('Impressora')->imprimir_senha($dados);
            $::chamar = undef;
            $::senha_timer = EV::timer( 3, 0, \&limpar_senha );
        }
    }
    else {
        $::chamar = undef;
        &limpar_senha;
    }
}

sub escalonar_senha {
    if ( $::connection->is_connected ) {
        my $dados =
          Fila::Senha->model('SOAP::Senha')
          ->escalonar_senha( { local => { id_local => 2 } } );
        if ( $dados->{Fault} ) {
            warn 'Erro ao escalonar senha. ' . $dados->{Fault}{faultstring};
        }
        else {
            warn 'Escalonar senha';
        }
    }
    my ( $hora, $minuto ) = (localtime)[ 2, 1 ];
    my $h = $::hora->get_value_as_int;
    my $m = $::minuto->get_value_as_int;
    if ( $hora == $h ) {
        if ( $minuto > $m ) {
            $::minuto->set_value($minuto);
        }
    }
    elsif ( $hora > $h ) {
        $::hora->set_value($hora);
        $::minuto->set_value($minuto);
    }
}

sub limpar_senha {
    if ( $::connection->is_connected ) {
        my $dados_local =
          Fila::Senha->model('SOAP::Senha')->dados_local( { local => {} } );
        if (   $dados_local->{Fault}
            && $dados_local->{Fault}{faultstring} =~ /Permissao Negada/ )
        {
            Fila::Senha->model('Emissor')->bloquear;
        }
        else {
            Fila::Senha->model('Emissor')->abrir;
        }
        &atualizar_categorias;
    }
    else {
        Fila::Senha->model('Emissor')->bloquear;
        &atualizar_categorias;
    }
}

# Inicializar uma conexão principal de controle que ira fazer a
# inicializacao

$::connection =
  Net::XMPP2::Connection->new( %{ Fila::Senha->config->{'Engine::XMPP2'} },
    resource => 'Main Connection' );

$::connection->reg_cb(
    bind_error => sub {
        warn 'Error binding to resource' . localtime();
        EV::unloop(EV::UNLOOP_ALL);
    },

    iq_auth_error => sub {
        warn 'Authentication error ' . localtime();
        EV::unloop(EV::UNLOOP_ALL);
    },

    sasl_error => sub {
        warn 'Authentication error ' . localtime();
        EV::unloop(EV::UNLOOP_ALL);
    },

    disconnect => sub {
        warn 'disconnected ' . localtime();
        $::connection->connect;
    },

    stream_error => sub {
        warn 'Connection error.';
        EV::unloop(EV::UNLOOP_ALL);
    },

    stream_ready => sub {
        $::connection->send_presence( 'available', sub { } );

        Fila::Senha->model('SOAP')->transport->connection($::connection);
        Fila::Senha->model('SOAP')
          ->transport->addrs( ['motor@gestao.fila.vhost/ws/gestao/senha'] );

        our $dados_local =
          Fila::Senha->model('SOAP::Senha')->dados_local( { local => {} } );

        if (   $dados_local->{Fault}
            && $dados_local->{Fault}{faultstring} =~ /Permissao Negada/ )
        {
            warn 'Local está fechado. Vai esperar uma notificacao.';
            Fila::Senha->model('Emissor')->bloquear;
        }
        elsif ( $dados_local->{Fault} ) {
            warn 'Erro ao obter os dados do local: '
              . $dados_local->{Fault}{faultstring};
            EV::unloop( EV::UNLOOP_ALL() );
        }
        else {
            warn 'Abrindo para senhas';
            Fila::Senha->model('Emissor')->abrir;
        }
        $::imprimir_senha       = EV::timer( 1, 1,  \&imprimir_senha );
        $::escalonar_timer      = EV::timer( 1, 30, \&escalonar_senha );
        $::atualizar_categorias = EV::timer( 1, 0,  \&atualizar_categorias );
        eval { Fila::Senha->run(); };
        if ($@) {
            warn 'Error running application: ' . $@;
            EV::unloop(EV::UNLOOP_ALL);
        }
    }
);

unless ( $::connection->connect ) {
    EV::unloop(EV::UNLOOP_ALL);
    die 'Cannot connect to server';
}
else {
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

