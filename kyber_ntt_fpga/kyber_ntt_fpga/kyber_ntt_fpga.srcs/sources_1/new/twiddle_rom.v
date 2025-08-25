// twiddle_rom.v
// 旋转因子ROM

`include "kyber_params.v"

module twiddle_rom (
    input  clk,
    input  [TW_ADDR_WIDTH-1:0] addr,     // 旋转因子地址
    input  [MODE_WIDTH-1:0] mode,        // 操作模式（NTT/INTT）
    output reg [DATA_WIDTH-1:0] twiddle  // 旋转因子输出
);

// 预计算的Kyber旋转因子表
// 根据论文Algorithm 1，使用ζ^BitRev7(k)计算

reg [DATA_WIDTH-1:0] ntt_twiddles [0:127];
reg [DATA_WIDTH-1:0] intt_twiddles [0:127];

// 循环变量声明
integer i;

// 初始化旋转因子表
initial begin
    // NTT正变换旋转因子 (ζ = 17, q = 3329)
    ntt_twiddles[0]  = 12'd1;    // zeta^(bitrev7(0)=0)
    ntt_twiddles[1]  = 12'd1729; // zeta^(bitrev7(1)=64)
    ntt_twiddles[2]  = 12'd2580; // zeta^(bitrev7(2)=32)
    ntt_twiddles[3]  = 12'd3289; // zeta^(bitrev7(3)=96)
    ntt_twiddles[4]  = 12'd2642; // zeta^(bitrev7(4)=16)
    ntt_twiddles[5]  = 12'd630;  // zeta^(bitrev7(5)=80)
    ntt_twiddles[6]  = 12'd1897; // zeta^(bitrev7(6)=48)
    ntt_twiddles[7]  = 12'd848;  // zeta^(bitrev7(7)=112)
    ntt_twiddles[8]  = 12'd1062; // zeta^(bitrev7(8)=8)
    ntt_twiddles[9]  = 12'd1919; // zeta^(bitrev7(9)=72)
    ntt_twiddles[10] = 12'd193;  // zeta^(bitrev7(10)=40)
    ntt_twiddles[11] = 12'd797;  // zeta^(bitrev7(11)=104)
    ntt_twiddles[12] = 12'd2786; // zeta^(bitrev7(12)=24)
    ntt_twiddles[13] = 12'd3260; // zeta^(bitrev7(13)=88)
    ntt_twiddles[14] = 12'd569;  // zeta^(bitrev7(14)=56)
    ntt_twiddles[15] = 12'd1746; // zeta^(bitrev7(15)=120)
    ntt_twiddles[16] = 12'd296;  // zeta^(bitrev7(16)=4)
    ntt_twiddles[17] = 12'd2447; // zeta^(bitrev7(17)=68)
    ntt_twiddles[18] = 12'd1339; // zeta^(bitrev7(18)=36)
    ntt_twiddles[19] = 12'd1476; // zeta^(bitrev7(19)=100)
    ntt_twiddles[20] = 12'd3046; // zeta^(bitrev7(20)=20)
    ntt_twiddles[21] = 12'd56;   // zeta^(bitrev7(21)=84)
    ntt_twiddles[22] = 12'd2240; // zeta^(bitrev7(22)=52)
    ntt_twiddles[23] = 12'd1333; // zeta^(bitrev7(23)=116)
    ntt_twiddles[24] = 12'd1426; // zeta^(bitrev7(24)=12)
    ntt_twiddles[25] = 12'd2094; // zeta^(bitrev7(25)=76)
    ntt_twiddles[26] = 12'd535;  // zeta^(bitrev7(26)=44)
    ntt_twiddles[27] = 12'd2882; // zeta^(bitrev7(27)=108)
    ntt_twiddles[28] = 12'd2393; // zeta^(bitrev7(28)=28)
    ntt_twiddles[29] = 12'd2879; // zeta^(bitrev7(29)=92)
    ntt_twiddles[30] = 12'd1974; // zeta^(bitrev7(30)=60)
    ntt_twiddles[31] = 12'd821;  // zeta^(bitrev7(31)=124)
    ntt_twiddles[32] = 12'd289;  // zeta^(bitrev7(32)=2)
    ntt_twiddles[33] = 12'd331;  // zeta^(bitrev7(33)=66)
    ntt_twiddles[34] = 12'd3253; // zeta^(bitrev7(34)=34)
    ntt_twiddles[35] = 12'd1756; // zeta^(bitrev7(35)=98)
    ntt_twiddles[36] = 12'd1197; // zeta^(bitrev7(36)=18)
    ntt_twiddles[37] = 12'd2304; // zeta^(bitrev7(37)=82)
    ntt_twiddles[38] = 12'd2277; // zeta^(bitrev7(38)=50)
    ntt_twiddles[39] = 12'd2055; // zeta^(bitrev7(39)=114)
    ntt_twiddles[40] = 12'd650;  // zeta^(bitrev7(40)=10)
    ntt_twiddles[41] = 12'd1977; // zeta^(bitrev7(41)=74)
    ntt_twiddles[42] = 12'd2513; // zeta^(bitrev7(42)=42)
    ntt_twiddles[43] = 12'd632;  // zeta^(bitrev7(43)=106)
    ntt_twiddles[44] = 12'd2865; // zeta^(bitrev7(44)=26)
    ntt_twiddles[45] = 12'd33;   // zeta^(bitrev7(45)=90)
    ntt_twiddles[46] = 12'd1320; // zeta^(bitrev7(46)=58)
    ntt_twiddles[47] = 12'd1915; // zeta^(bitrev7(47)=122)
    ntt_twiddles[48] = 12'd2319; // zeta^(bitrev7(48)=6)
    ntt_twiddles[49] = 12'd1435; // zeta^(bitrev7(49)=70)
    ntt_twiddles[50] = 12'd807;  // zeta^(bitrev7(50)=38)
    ntt_twiddles[51] = 12'd452;  // zeta^(bitrev7(51)=102)
    ntt_twiddles[52] = 12'd1438; // zeta^(bitrev7(52)=22)
    ntt_twiddles[53] = 12'd2868; // zeta^(bitrev7(53)=86)
    ntt_twiddles[54] = 12'd1534; // zeta^(bitrev7(54)=54)
    ntt_twiddles[55] = 12'd2402; // zeta^(bitrev7(55)=118)
    ntt_twiddles[56] = 12'd2647; // zeta^(bitrev7(56)=14)
    ntt_twiddles[57] = 12'd2617; // zeta^(bitrev7(57)=78)
    ntt_twiddles[58] = 12'd1481; // zeta^(bitrev7(58)=46)
    ntt_twiddles[59] = 12'd648;  // zeta^(bitrev7(59)=110)
    ntt_twiddles[60] = 12'd2474; // zeta^(bitrev7(60)=30)
    ntt_twiddles[61] = 12'd3110; // zeta^(bitrev7(61)=94)
    ntt_twiddles[62] = 12'd1227; // zeta^(bitrev7(62)=62)
    ntt_twiddles[63] = 12'd910;  // zeta^(bitrev7(63)=126)
    ntt_twiddles[64] = 12'd17;   // zeta^(bitrev7(64)=1)
    ntt_twiddles[65] = 12'd2761; // zeta^(bitrev7(65)=65)
    ntt_twiddles[66] = 12'd583;  // zeta^(bitrev7(66)=33)
    ntt_twiddles[67] = 12'd2649; // zeta^(bitrev7(67)=97)
    ntt_twiddles[68] = 12'd1637; // zeta^(bitrev7(68)=17)
    ntt_twiddles[69] = 12'd723;  // zeta^(bitrev7(69)=81)
    ntt_twiddles[70] = 12'd2288; // zeta^(bitrev7(70)=49)
    ntt_twiddles[71] = 12'd1100; // zeta^(bitrev7(71)=113)
    ntt_twiddles[72] = 12'd1409; // zeta^(bitrev7(72)=9)
    ntt_twiddles[73] = 12'd2662; // zeta^(bitrev7(73)=73)
    ntt_twiddles[74] = 12'd3281; // zeta^(bitrev7(74)=41)
    ntt_twiddles[75] = 12'd233;  // zeta^(bitrev7(75)=105)
    ntt_twiddles[76] = 12'd756;  // zeta^(bitrev7(76)=25)
    ntt_twiddles[77] = 12'd2156; // zeta^(bitrev7(77)=89)
    ntt_twiddles[78] = 12'd3015; // zeta^(bitrev7(78)=57)
    ntt_twiddles[79] = 12'd3050; // zeta^(bitrev7(79)=121)
    ntt_twiddles[80] = 12'd1703; // zeta^(bitrev7(80)=5)
    ntt_twiddles[81] = 12'd1651; // zeta^(bitrev7(81)=69)
    ntt_twiddles[82] = 12'd2789; // zeta^(bitrev7(82)=37)
    ntt_twiddles[83] = 12'd1789; // zeta^(bitrev7(83)=101)
    ntt_twiddles[84] = 12'd1847; // zeta^(bitrev7(84)=21)
    ntt_twiddles[85] = 12'd952;  // zeta^(bitrev7(85)=85)
    ntt_twiddles[86] = 12'd1461; // zeta^(bitrev7(86)=53)
    ntt_twiddles[87] = 12'd2687; // zeta^(bitrev7(87)=117)
    ntt_twiddles[88] = 12'd939;  // zeta^(bitrev7(88)=13)
    ntt_twiddles[89] = 12'd2308; // zeta^(bitrev7(89)=77)
    ntt_twiddles[90] = 12'd2437; // zeta^(bitrev7(90)=45)
    ntt_twiddles[91] = 12'd2388; // zeta^(bitrev7(91)=109)
    ntt_twiddles[92] = 12'd733;  // zeta^(bitrev7(92)=29)
    ntt_twiddles[93] = 12'd2337; // zeta^(bitrev7(93)=93)
    ntt_twiddles[94] = 12'd268;  // zeta^(bitrev7(94)=61)
    ntt_twiddles[95] = 12'd641;  // zeta^(bitrev7(95)=125)
    ntt_twiddles[96] = 12'd1584; // zeta^(bitrev7(96)=3)
    ntt_twiddles[97] = 12'd2298; // zeta^(bitrev7(97)=67)
    ntt_twiddles[98] = 12'd2037; // zeta^(bitrev7(98)=35)
    ntt_twiddles[99] = 12'd3220; // zeta^(bitrev7(99)=99)
    ntt_twiddles[100]= 12'd375;  // zeta^(bitrev7(100)=19)
    ntt_twiddles[101]= 12'd2549; // zeta^(bitrev7(101)=83)
    ntt_twiddles[102]= 12'd2090; // zeta^(bitrev7(102)=51)
    ntt_twiddles[103]= 12'd1645; // zeta^(bitrev7(103)=115)
    ntt_twiddles[104]= 12'd1063; // zeta^(bitrev7(104)=11)
    ntt_twiddles[105]= 12'd319;  // zeta^(bitrev7(105)=75)
    ntt_twiddles[106]= 12'd2773; // zeta^(bitrev7(106)=43)
    ntt_twiddles[107]= 12'd757;  // zeta^(bitrev7(107)=107)
    ntt_twiddles[108]= 12'd2099; // zeta^(bitrev7(108)=27)
    ntt_twiddles[109]= 12'd561;  // zeta^(bitrev7(109)=91)
    ntt_twiddles[110]= 12'd2466; // zeta^(bitrev7(110)=59)
    ntt_twiddles[111]= 12'd2594; // zeta^(bitrev7(111)=123)
    ntt_twiddles[112]= 12'd2804; // zeta^(bitrev7(112)=7)
    ntt_twiddles[113]= 12'd1092; // zeta^(bitrev7(113)=71)
    ntt_twiddles[114]= 12'd403;  // zeta^(bitrev7(114)=39)
    ntt_twiddles[115]= 12'd1026; // zeta^(bitrev7(115)=103)
    ntt_twiddles[116]= 12'd1143; // zeta^(bitrev7(116)=23)
    ntt_twiddles[117]= 12'd2150; // zeta^(bitrev7(117)=87)
    ntt_twiddles[118]= 12'd2775; // zeta^(bitrev7(118)=55)
    ntt_twiddles[119]= 12'd886;  // zeta^(bitrev7(119)=119)
    ntt_twiddles[120]= 12'd1722; // zeta^(bitrev7(120)=15)
    ntt_twiddles[121]= 12'd1212; // zeta^(bitrev7(121)=79)
    ntt_twiddles[122]= 12'd1874; // zeta^(bitrev7(122)=47)
    ntt_twiddles[123]= 12'd1029; // zeta^(bitrev7(123)=111)
    ntt_twiddles[124]= 12'd2110; // zeta^(bitrev7(124)=31)
    ntt_twiddles[125]= 12'd2935; // zeta^(bitrev7(125)=95)
    ntt_twiddles[126]= 12'd885;  // zeta^(bitrev7(126)=63)
    ntt_twiddles[127]= 12'd2154; // zeta^(bitrev7(127)=127)
    end
    
    // INTT逆变换旋转因子（是NTT旋转因子的逆元）
initial begin
    intt_twiddles[0]  = 12'd1;    // inverse of 1
    intt_twiddles[1]  = 12'd1600; // inverse of 1729
    intt_twiddles[2]  = 12'd40;   // inverse of 2580
    intt_twiddles[3]  = 12'd749;  // inverse of 3289
    intt_twiddles[4]  = 12'd2481; // inverse of 2642
    intt_twiddles[5]  = 12'd1432; // inverse of 630
    intt_twiddles[6]  = 12'd2699; // inverse of 1897
    intt_twiddles[7]  = 12'd687;  // inverse of 848
    intt_twiddles[8]  = 12'd1583; // inverse of 1062
    intt_twiddles[9]  = 12'd2760; // inverse of 1919
    intt_twiddles[10] = 12'd69;   // inverse of 193
    intt_twiddles[11] = 12'd543;  // inverse of 797
    intt_twiddles[12] = 12'd2532; // inverse of 2786
    intt_twiddles[13] = 12'd3136; // inverse of 3260
    intt_twiddles[14] = 12'd1410; // inverse of 569
    intt_twiddles[15] = 12'd2267; // inverse of 1746
    intt_twiddles[16] = 12'd2508; // inverse of 296
    intt_twiddles[17] = 12'd1355; // inverse of 2447
    intt_twiddles[18] = 12'd450;  // inverse of 1339
    intt_twiddles[19] = 12'd936;  // inverse of 1476
    intt_twiddles[20] = 12'd447;  // inverse of 3046
    intt_twiddles[21] = 12'd2794; // inverse of 56
    intt_twiddles[22] = 12'd1235; // inverse of 2240
    intt_twiddles[23] = 12'd1903; // inverse of 1333
    intt_twiddles[24] = 12'd1996; // inverse of 1426
    intt_twiddles[25] = 12'd1089; // inverse of 2094
    intt_twiddles[26] = 12'd3273; // inverse of 535
    intt_twiddles[27] = 12'd283;  // inverse of 2882
    intt_twiddles[28] = 12'd1853; // inverse of 2393
    intt_twiddles[29] = 12'd1990; // inverse of 2879
    intt_twiddles[30] = 12'd882;  // inverse of 1974
    intt_twiddles[31] = 12'd3033; // inverse of 821
    intt_twiddles[32] = 12'd2419; // inverse of 289
    intt_twiddles[33] = 12'd2102; // inverse of 331
    intt_twiddles[34] = 12'd219;  // inverse of 3253
    intt_twiddles[35] = 12'd855;  // inverse of 1756
    intt_twiddles[36] = 12'd2681; // inverse of 1197
    intt_twiddles[37] = 12'd1848; // inverse of 2304
    intt_twiddles[38] = 12'd712;  // inverse of 2277
    intt_twiddles[39] = 12'd682;  // inverse of 2055
    intt_twiddles[40] = 12'd927;  // inverse of 650
    intt_twiddles[41] = 12'd1795; // inverse of 1977
    intt_twiddles[42] = 12'd461;  // inverse of 2513
    intt_twiddles[43] = 12'd1891; // inverse of 632
    intt_twiddles[44] = 12'd2877; // inverse of 2865
    intt_twiddles[45] = 12'd2522; // inverse of 33
    intt_twiddles[46] = 12'd1894; // inverse of 1320
    intt_twiddles[47] = 12'd1010; // inverse of 1915
    intt_twiddles[48] = 12'd1414; // inverse of 2319
    intt_twiddles[49] = 12'd2009; // inverse of 1435
    intt_twiddles[50] = 12'd3296; // inverse of 807
    intt_twiddles[51] = 12'd464;  // inverse of 452
    intt_twiddles[52] = 12'd2697; // inverse of 1438
    intt_twiddles[53] = 12'd816;  // inverse of 2868
    intt_twiddles[54] = 12'd1352; // inverse of 1534
    intt_twiddles[55] = 12'd2679; // inverse of 2402
    intt_twiddles[56] = 12'd1274; // inverse of 2647
    intt_twiddles[57] = 12'd1052; // inverse of 2617
    intt_twiddles[58] = 12'd1025; // inverse of 1481
    intt_twiddles[59] = 12'd2132; // inverse of 648
    intt_twiddles[60] = 12'd1573; // inverse of 2474
    intt_twiddles[61] = 12'd76;   // inverse of 3110
    intt_twiddles[62] = 12'd2998; // inverse of 1227
    intt_twiddles[63] = 12'd3040; // inverse of 910
    intt_twiddles[64] = 12'd1175; // inverse of 17
    intt_twiddles[65] = 12'd2444; // inverse of 2761
    intt_twiddles[66] = 12'd394;  // inverse of 583
    intt_twiddles[67] = 12'd1219; // inverse of 2649
    intt_twiddles[68] = 12'd2300; // inverse of 1637
    intt_twiddles[69] = 12'd1455; // inverse of 723
    intt_twiddles[70] = 12'd2117; // inverse of 2288
    intt_twiddles[71] = 12'd1607; // inverse of 1100
    intt_twiddles[72] = 12'd2443; // inverse of 1409
    intt_twiddles[73] = 12'd554;  // inverse of 2662
    intt_twiddles[74] = 12'd1179; // inverse of 3281
    intt_twiddles[75] = 12'd2186; // inverse of 233
    intt_twiddles[76] = 12'd2303; // inverse of 756
    intt_twiddles[77] = 12'd2926; // inverse of 2156
    intt_twiddles[78] = 12'd2237; // inverse of 3015
    intt_twiddles[79] = 12'd525;  // inverse of 3050
    intt_twiddles[80] = 12'd735;  // inverse of 1703
    intt_twiddles[81] = 12'd863;  // inverse of 1651
    intt_twiddles[82] = 12'd2768; // inverse of 2789
    intt_twiddles[83] = 12'd1230; // inverse of 1789
    intt_twiddles[84] = 12'd2572; // inverse of 1847
    intt_twiddles[85] = 12'd556;  // inverse of 952
    intt_twiddles[86] = 12'd3010; // inverse of 1461
    intt_twiddles[87] = 12'd2266; // inverse of 2687
    intt_twiddles[88] = 12'd1684; // inverse of 939
    intt_twiddles[89] = 12'd1239; // inverse of 2308
    intt_twiddles[90] = 12'd780;  // inverse of 2437
    intt_twiddles[91] = 12'd2954; // inverse of 2388
    intt_twiddles[92] = 12'd109;  // inverse of 733
    intt_twiddles[93] = 12'd1292; // inverse of 2337
    intt_twiddles[94] = 12'd1031; // inverse of 268
    intt_twiddles[95] = 12'd1745; // inverse of 641
    intt_twiddles[96] = 12'd2688; // inverse of 1584
    intt_twiddles[97] = 12'd3061; // inverse of 2298
    intt_twiddles[98] = 12'd992;  // inverse of 2037
    intt_twiddles[99] = 12'd2596; // inverse of 3220
    intt_twiddles[100]= 12'd941;  // inverse of 375
    intt_twiddles[101]= 12'd892;  // inverse of 2549
    intt_twiddles[102]= 12'd1021; // inverse of 2090
    intt_twiddles[103]= 12'd2390; // inverse of 1645
    intt_twiddles[104]= 12'd642;  // inverse of 1063
    intt_twiddles[105]= 12'd1868; // inverse of 319
    intt_twiddles[106]= 12'd2377; // inverse of 2773
    intt_twiddles[107]= 12'd1482; // inverse of 757
    intt_twiddles[108]= 12'd1540; // inverse of 2099
    intt_twiddles[109]= 12'd540;  // inverse of 561
    intt_twiddles[110]= 12'd1678; // inverse of 2466
    intt_twiddles[111]= 12'd1626; // inverse of 2594
    intt_twiddles[112]= 12'd279;  // inverse of 2804
    intt_twiddles[113]= 12'd314;  // inverse of 1092
    intt_twiddles[114]= 12'd1173; // inverse of 403
    intt_twiddles[115]= 12'd2573; // inverse of 1026
    intt_twiddles[116]= 12'd3096; // inverse of 1143
    intt_twiddles[117]= 12'd48;   // inverse of 2150
    intt_twiddles[118]= 12'd667;  // inverse of 2775
    intt_twiddles[119]= 12'd1920; // inverse of 886
    intt_twiddles[120]= 12'd2229; // inverse of 1722
    intt_twiddles[121]= 12'd1041; // inverse of 1212
    intt_twiddles[122]= 12'd2606; // inverse of 1874
    intt_twiddles[123]= 12'd1692; // inverse of 1029
    intt_twiddles[124]= 12'd680;  // inverse of 2110
    intt_twiddles[125]= 12'd2746; // inverse of 2935
    intt_twiddles[126]= 12'd568;  // inverse of 885
    intt_twiddles[127]= 12'd3312; // inverse of 2154
end

// 旋转因子输出逻辑
always @(posedge clk) begin
    case (mode)
        MODE_NTT: begin
            twiddle <= ntt_twiddles[addr];
        end
        MODE_INTT: begin  
            twiddle <= intt_twiddles[addr];
        end
        default: begin
            twiddle <= 1; // 默认值
        end
    endcase
end

endmodule

// 简化的多端口旋转因子ROM，为8个蝶形单元提供相同的旋转因子
module multi_port_twiddle_rom (
    input  clk,
    input  [TW_ADDR_WIDTH-1:0] addr,     // 单个地址输入
    input  [MODE_WIDTH-1:0] mode,
    output [DATA_WIDTH-1:0] twiddle      // 单个旋转因子输出
);

// 使用单个旋转因子ROM实例
twiddle_rom tw_rom_inst (
    .clk(clk),
    .addr(addr),
    .mode(mode),
    .twiddle(twiddle)
);

endmodule