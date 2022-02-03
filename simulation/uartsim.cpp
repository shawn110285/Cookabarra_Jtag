
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <poll.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <signal.h>
#include <ctype.h>

#include "uartsim.h"

/* example on usage
	UARTSIM  * uart = NULL;
	uart = new(UARTSIM);
	unsigned   baudclocks = 0x1B8;
    uart->setup(baudclocks);

	int t = 1;
	while(1)
	{
		...
        if(t>2)   //skip the reset process
		{
		    tb->uart_rx_pin = (*uart)(tb->uart_tx_pin);  //get the uart_tx and sent the char via rx_pin to riscv cpu
		}
		t++;
	}
 */

UARTSIM::UARTSIM(void)
{
	setup(0x1B8);	// Set us up for a baud rate of CLK/25
	m_rx_baudcounter = 0;
	m_tx_baudcounter = 0;
	m_rx_state = RXIDLE;
	m_tx_state = TXIDLE;
}

void	UARTSIM::setup(unsigned isetup)
{
	m_baud_counts = (isetup & 0x0ffffff);
}

int	UARTSIM::operator()(const int i_tx)
{
	int	o_rx = 1, nr = 0;
	m_last_tx = i_tx;
	if (m_rx_state == RXIDLE)
	{
		if (!i_tx)  // from high to low, start the transmition
		{
			m_rx_state = RXDATA;
			m_rx_baudcounter = m_baud_counts+m_baud_counts/2-1;
			m_rx_bits    = 0;
			m_rx_data    = 0;
		}
	}
	else if (m_rx_baudcounter <= 0)
	{
		if (m_rx_bits >= 8)
		{
			m_rx_state = RXIDLE;
			putchar(m_rx_data);
			fflush(stdout);
		}
		else
		{
			m_rx_bits++;;
			m_rx_data = ((i_tx&1) ? 0x80 : 0) | (m_rx_data>>1);
		}
		m_rx_baudcounter = m_baud_counts-1;
	}
	else
	{
		m_rx_baudcounter--;
	}

	if (m_tx_state == TXIDLE)
	{
		struct	pollfd	pb;
		pb.fd = STDIN_FILENO;
		pb.events = POLLIN;
		if (poll(&pb, 1, 0) < 0)
		{
			perror("Polling error:");
		}

		if (pb.revents & POLLIN)
		{
			char	buf[1];
			nr = read(STDIN_FILENO, buf, 1);
			if (1 == nr)
			{
				// printf( "UARTSIM()::read(%c)\n", buf[0]);
				m_tx_data = (-1<<10) |((buf[0]<<1)&0x01fe);
				m_tx_busy = (1<<(10))-1;
				m_tx_state = TXDATA;
				o_rx = 0;
				m_tx_baudcounter = m_baud_counts-1;
			}
			else if (nr < 0)
			{
				fprintf(stderr, "uart read console ERR!\n");
			}
		}
	}
	else if (m_tx_baudcounter <= 0)
	{
		m_tx_data >>= 1;
		m_tx_busy >>= 1;
		if (!m_tx_busy)
			m_tx_state = TXIDLE;
		else
			m_tx_baudcounter = m_baud_counts-1;
		o_rx = m_tx_data&1;
	}
	else
	{
		m_tx_baudcounter--;
		o_rx = m_tx_data&1;
	}

	return o_rx;
}
