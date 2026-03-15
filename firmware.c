// example firmware: run aes, then print "Hi" over uart.
// memory map: aes at 0x8000, uart at 0x9000 (data) and 0x9004 (status).

#define AES_BASE  0x8000
#define UART_DATA 0x9000
#define UART_STAT 0x9004

static volatile unsigned int *const aes  = (volatile unsigned int *)AES_BASE;
static volatile unsigned int *const uart = (volatile unsigned int *)UART_DATA;

static void uart_putchar(unsigned int c) {
    while (!((*((volatile unsigned int *)UART_STAT)) & 1u))  // wait tx_ready
        ;
    *uart = c & 0xff;
}

int main(void) {
    // load key and block, start aes
    aes[0] = 0x00112233;
    aes[1] = 0x44556677;
    aes[2] = 0x8899aabb;
    aes[3] = 0xccddeeff;
    aes[4] = 0x01234567;
    aes[5] = 0x89abcdef;
    aes[6] = 0xfedcba98;
    aes[7] = 0x76543210;
    aes[8] = 1;
    while (!(aes[8] & 1u))  // wait ready
        ;

    // print "Hi\n" over uart (or use result bytes: uart_putchar(aes[0xc] & 0xff); etc.)
    uart_putchar('H');
    uart_putchar('i');
    uart_putchar('\n');

    for (;;)
        ;
}
