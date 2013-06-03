package Fila::Senha;
use utf8;
use 5.010;
BEGIN { $ENV{LC_ALL} = "pt_BR"; }

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
    die 'Porta da impressora nao configurada'
      unless $porta_impressora = $portas->{impressora};

    die 'Porta do emissor nao configurada'
      unless $porta_emissor = $portas->{emissor};

    $categorias = __PACKAGE__->config->{categorias}
      or die 'Categorias nao configuradas.';

    $Fila::Senha::horario       = __PACKAGE__->config->{horario}       || 0;
    $Fila::Senha::identificacao = __PACKAGE__->config->{identificacao} || 0;
    $Fila::Senha::font_face = __PACKAGE__->config->{font_face}  || 'Arial';
    $Fila::Senha::fg_color  = __PACKAGE__->config->{'fg_color'} || '#000000';
    $Fila::Senha::bg_color  = __PACKAGE__->config->{'bg_color'} || '#FFFFFF';
}

$::gladexml      = undef;
$::chamar        = undef;
$::current_modal = undef;

# %::window;
# %::entry;
# %::label;
# %::button;
# %::spin;

{
    $::gladexml =
      Gtk2::GladeXML->new('/usr/share/fila/Fila-Senha/script/Fila-Senha.glade')
      or die 'died: ' . $!;
    $::gladexml->signal_autoconnect_from_package(__PACKAGE__);

    foreach my $w (qw/ window1 w1x10 horario identificacao /) {
        $::window{$w} = $::gladexml->get_widget($w);

        if ( $w eq 'window1' ) {
            $::window{$w}->resize( 1024, 768 );
        }
        else {
            $::window{$w}->resize( 880, 660 );
        }

        my $f = "/usr/share/fila/Fila-Senha/bg-" . $w . ".png";

        if ( -f $f ) {
            my $back_pixbuf = Gtk2::Gdk::Pixbuf->new_from_file($f);
            my ( $pixmap, $mask ) = $back_pixbuf->render_pixmap_and_mask(255);
            my $style = $::window{$w}->get_style;
            $style = $style->copy;
            $style->bg_pixmap( "normal", $pixmap );
            $::window{$w}->set_style($style);
        }

        $::window{$w}->modify_bg( $::window{$w}->state,
          Gtk2::Gdk::Color->parse($Fila::Senha::background_color) );
        $::window{$w}->set_opacity(0.9);
    }

    foreach my $l (
        qw /
        header footer copyright horario_header identificacao_header
        w1x10_header w1x10_caminho
        /
      )
    {
        $::label{$l} = $::gladexml->get_widget($l);
        $::label{$l}->modify_font(
            Gtk2::Pango::FontDescription->from_string(
                $Fila::Senha::font_face . " 10"
            )
        );
        $::label{$l}->modify_fg( $::label{$l}->state,
            Gtk2::Gdk::Color->parse($Fila::Senha::fg_color) );
        $::label{$l}->modify_bg( $::label{$l}->state,
            Gtk2::Gdk::Color->parse($Fila::Senha::bg_color) );
    }

    foreach my $l (qw/ w1x10_caminho copyright / ) {
        $::label{$l}->modify_font(
            Gtk2::Pango::FontDescription->from_string(
                $Fila::Senha::font_face . " 7"
            )
        );
    }

    foreach my $e (qw / identificacao_entry /) {
        $::entry{$e} = $::gladexml->get_widget($e) or die $!;
        $::entry{$e}->modify_font(
            Gtk2::Pango::FontDescription->from_string(
                $Fila::Senha::font_face . " 40"
            )
        );
        $::entry{$e}->modify_fg( $::entry{$e}->state,
            Gtk2::Gdk::Color->parse($Fila::Senha::fg_color) );
        $::entry{$e}->modify_bg( $::entry{$e}->state,
            Gtk2::Gdk::Color->parse($Fila::Senha::bg_color) );
    }

    foreach my $b (
        qw /
        d0 d1 d2 d3 d4 d5 d6 d7 d8 d9 d0
        c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 
        /
      )
    {
        $::button{$b} = $::gladexml->get_widget($b) or die $b;
        $::button{$b}->child->modify_font(
            Gtk2::Pango::FontDescription->from_string(
                $Fila::Senha::font_face . " 20"
            )
        );
    }

    foreach my $b (
        qw /
        horario_cancelar horario_ok identificacao_cancelar identificacao_ok w1x10_cancelar w1x10_voltar
        /
      )
    {
        $::button{$b} = $::gladexml->get_widget($b) or die $b;
        $::button{$b}->child->modify_font(
            Gtk2::Pango::FontDescription->from_string(
                $Fila::Senha::font_face . " 10"
            )
        );
    }

# Os widgets de horário devem ser inicializados mesmo que não se permita agendar

    foreach my $s (qw / hora minuto/) {
        $::spin{$s} = $::gladexml->get_widget($s) or die $!;
        $::spin{$s}->modify_font(
            Gtk2::Pango::FontDescription->from_string(
                $Fila::Senha::font_face . " 40"
            )
        );
        $::spin{$s}->modify_fg( $::spin{$s}->state,
            Gtk2::Gdk::Color->parse($Fila::Senha::fg_color) );
        $::spin{$s}->modify_bg( $::spin{$s}->state,
            Gtk2::Gdk::Color->parse($Fila::Senha::bg_color) );
    }
    Gtk2::Window::fullscreen( $::window{'window1'} );

    $::label{'header'}->set_label($Fila::Senha::header);
    $::label{'footer'}->set_label($Fila::Senha::footer);
    $::window{'window1'}->fullscreen;
    $::window{'window1'}->set_opacity(0.9);
    $::window{'window1'}->show_all;
    &inicio;
}

sub inicio {
    $::last = time;
    $::entry{'identificacao_entry'}->set_text('');
    $::label{'w1x10_caminho'}->set_label('');
    if ($Fila::Senha::identificacao) {
        &identificacao;
    }
    elsif ($Fila::Senha::horario) {
        &horario;
    }
    else {
        &layout;
    }
}

sub layout {
    $::last = time; 
    if ( $Fila::Senha::layout eq 'w1x10' ) {
        &w1x10;
    }
    else {
        &w1x10;
    }
}

sub identificacao {
    $::last = time;
    $::current_modal->hide
      if defined $::current_modal
          and $::current_modal->get_name ne 'identificacao';
    $::current_modal = $::window{'identificacao'};
    $::current_modal->show;
}

sub on_identificacao_digit_clicked {
    my $self = shift;
    $::last = time;
    my $n    = $self->get_name;
    my $e    = $::entry{'identificacao_entry'}->get_text;
    $n =~ s/\D//g;
    $::entry{'identificacao_entry'}->set_text( $e . $n );
    $::entry{'identificacao_entry'}->show;
}

sub on_identificacao_ok_clicked {
    $::last = time;
    $::current_modal->hide;
    if ($Fila::Senha::horario) {
        &horario;
    }
    else {
        &layout;
    }
}

sub horario {
    $::last = time;
    $::current_modal->hide if $::current_modal->get_name ne 'horario';
    $::current_modal = $::window{'horario'};
    $::current_modal->show;
}

sub on_horario_ok_clicked {
    $::last = time;
    $::current_modal->hide;
    &layout;
}

sub w1x10 {
    $::current_modal->hide
      if defined $::current_modal && $::current_modal->get_name ne 'w1x10';
    $::current_modal = $::window{'w1x10'};
    my $l = $::label{'w1x10_caminho'}->get_label;
    $l = '' unless defined $l;
    my @b;
    if ($l) {
        @b = sort { lc($a) cmp lc($b) } grep { /^$l\// } keys %::categorias_ordem;
    }
    else {
        @b = sort { lc($a) cmp lc($b) } keys %::categorias_ordem;
    }
    $::current_modal->show;
    my @o;
    foreach my $b (@b) {
        my $n = $b;
        unless ( defined $n && $n =~ /\// ) {
            $o[ $::categorias_ordem{$b} ] = $n if defined $n;
        }
    }
    my %diff;
    @diff{@b} = 1;
    if ( keys %diff ) {
        delete @diff{ grep { defined $_ } @o };
    }
    my @diff;
    @diff = sort { lc($a) cmp lc($b)} keys %diff;
    foreach my $i ( 1 .. 10 ) {
        while ((!defined($o[$i])) and (my $n = shift @diff)) {
            if (defined $n && $n ne '') {
                if ( defined $n && defined $l && $l ne '' && $n =~ /^$l/ ) {
                    $n =~ s/^$l\/([^\/]+).*$/$1/;
                }
                elsif ( defined $n && $n && $n =~ /\// ) {
                    $n =~ s/^([^\/]+)\/.*$/$1/;
                }
		my $check = 0;
                foreach my $o (@o) {
		    $check = 1 if (defined $o) && ($n eq $o);
                    last if $check;
	        }
		unless ($check) {
                    $o[$i] = $n;
                }
            }
       }
    }
    foreach my $i ( 1 .. 10 ) {
        if ( defined $o[$i] ) {
            my $n = $o[$i];
            $::button{ 'c' . $i }->set_label($n);
            $::button{ 'c' . $i }->show;
        }
        else {
            $::button{ 'c' . $i }->hide;
        }
    }
    $::current_modal->show;
}

sub on_TabCatButton_clicked {
    my $self = shift;
    $::last = time;
    my $path = $::label{'w1x10_caminho'}->get_label;
    my $c;
    if ( $path ne '' ) {
        $c = $::label{'w1x10_caminho'}->get_label . '/' . $self->get_label;
    }
    else {
        $c = $self->get_label;
    }
    if ( exists $::categorias_id{$c} ) {
	$::current_modal->hide;
        $::chamar = $::categorias_id{$c};
    }
    else {
        $::label{'w1x10_caminho'}->set_label($c);
        &layout;
    }
}

sub on_w1x10_voltar_clicked {
    $::current_modal->hide;
    $::last = time;
    my $l = $::label{w1x10_caminho}->get_label;
    if ( $l =~ s/^(.*)(\/[^\/]+)$/$1/ ) {
        $::label{w1x10_caminho}->set_label($l);
        &layout;
    }
    else {
        $::label{w1x10_caminho}->set_label('');
        &layout;
    }
}

sub atualizar_categorias {
    my $i = 0;
    $::atualizar_categorias = EV::timer( 30, 0, \&atualizar_categorias );
    return &inicio unless defined $::current_modal;
    my $modal_name = $::current_modal->get_name if defined $::current_modal;
    my $now = time;
    my $last = $::last;
    if (($last + 60) < $now) {
	&inicio;
    }
    return if $modal_name eq 'horario' or $modal_name eq 'identificacao';
    my $caminho = $::label{'w1x10_caminho'}->get_label;
    if ( $caminho eq '' ) {
        &w1x10;
    }
    return 1;
}

sub imprimir_senha {
    if ( $::connection->is_connected && defined $::chamar ) {
        my $hora   = sprintf( '%02s', $::spin{'hora'}->get_value_as_int );
        my $minuto = sprintf( '%02s', $::spin{'minuto'}->get_value_as_int );
        warn $hora . $minuto;
        my $dt = DateTime->now(
            time_zone => 'local',

        );
        $dt->set(
            hour   => $hora,
            minute => $minuto,

        );


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
        }
        else {
            $::label{'footer'}->set_label( $dados->{atendimento}{senha} );
            Fila::Senha->model('Impressora')->imprimir_senha($dados);
            $::chamar = undef;
            $::senha_timer = EV::timer( 3, 0, \&limpar_senha );
	    &inicio;
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
    }
    my ( $hora, $minuto ) = (localtime)[ 2, 1 ];
    my $h = $::spin{'hora'}->get_value_as_int;
    my $m = $::spin{'minuto'}->get_value_as_int;
    if ( $hora == $h ) {
        if ( $minuto > $m ) {
            $::spin{'minuto'}->set_value($minuto);
        }
    }
    elsif ( $hora > $h ) {
        $::spin{'hora'}->set_value($hora);
        $::spin{'minuto'}->set_value($minuto);
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
	if ($::chamar && $::current_modal->get_name eq 'w1x10') {
		$::label{'w1x10_caminho'}->set_label('');	
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
        $::imprimir_senha       = EV::timer( 10, 2, \&imprimir_senha );
        $::escalonar_timer      = EV::timer( 10, 10, \&escalonar_senha );
        $::atualizar_categorias = EV::timer( 10, 0,  \&atualizar_categorias );
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

