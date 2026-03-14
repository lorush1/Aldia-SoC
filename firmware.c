#define AES_BASE 0x8000
static volatile unsigned int * const AES = (volatile unsigned int * const)AES_BASE;

int main(void)
{
    AES[0] = 0x00112233;
    AES[1] = 0x44556677;
    AES[2] = 0x8899aabb;
    AES[3] = 0xccddeeff;
    AES[4] = 0x01234567;
    AES[5] = 0x89abcdef;
    AES[6] = 0xfedcba98;
    AES[7] = 0x76543210;
    AES[8] = 1;
    for (;;)
        ;
}
