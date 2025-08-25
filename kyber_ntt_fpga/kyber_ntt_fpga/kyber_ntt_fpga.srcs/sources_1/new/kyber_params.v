// kyber_params.v
// Kyber NTT ���������ļ�

`ifndef KYBER_PARAMS_V
`define KYBER_PARAMS_V

// Kyber��������
parameter KYBER_Q = 3329;           // ģ�� q = 3329 = 13��2^8 + 1
parameter KYBER_N = 256;            // ����ʽ����
parameter KYBER_LOGN = 8;           // log2(N)

// ����λ��
parameter DATA_WIDTH = 16;          // ����λ��֧��0-3328��Χ��
parameter ADDR_WIDTH = 8;           // ��ַλ��256��Ԫ�أ�
parameter TW_ADDR_WIDTH = 7;        // ��ת���ӵ�ַλ��128����ת���ӣ�

// NTT��ز���
parameter NTT_STAGES = 7;           // NTT����׶���
parameter BUTTERFLY_NUM = 8;        // ���е��ε�Ԫ����

// BarrettԼ����ز��������q=3329�Ż���
parameter BARRETT_R = 24;           // BarrettԼ���Rֵλ��
parameter BARRETT_MU = 5039;        // �� = floor(2^R / q)��Ԥ����ĳ���

// �����ź�λ��
parameter MODE_WIDTH = 2;           // ����ģʽλ��
parameter STAGE_WIDTH = 3;          // �׶μ�����λ��

// ����ģʽ����
parameter MODE_NTT = 2'b00;         // NTT���任
parameter MODE_INTT = 2'b01;        // INTT��任  
parameter MODE_PWM = 2'b10;         // ���ģʽ

// ״̬��״̬����
parameter STATE_WIDTH = 3;
parameter STATE_IDLE = 3'b000;      // ����״̬
parameter STATE_LOAD = 3'b001;      // ���ݼ���
parameter STATE_COMPUTE = 3'b010;   // ����״̬
parameter STATE_OUTPUT = 3'b011;    // ���״̬

// ʱ�����
parameter LOAD_CYCLES = 16;         // ���ݼ���������
parameter STAGE_CYCLES = 30;        // ÿ�׶μ���������
parameter OUTPUT_CYCLES = 16;       // ���������

// �ڴ����
parameter RAM_DEPTH = 256;          // RAM���
parameter RAM_WIDTH = DATA_WIDTH;   // RAMλ��

`endif // KYBER_PARAMS_V