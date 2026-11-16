function pop1 = FENJIEWUSHANG_PARALLEL_ALL()
warning off

%% 并行设置
if isempty(gcp('nocreate'))
    parpool('local', 6);  % 根据CPU核心数调整
end

%% 参数设置
num_patients = 15;      % 病人数
num_experiments = 10;   % 每个病人的重复实验次数
Max_CalNum = 30000;     % 最大评估次数
popnum = 300;           % 种群大小
S = 5;                  % 初始稀疏度参数

%% 对所有实验（病人×实验）并行处理
parfor idx = 1:(num_patients * num_experiments)
    % 计算当前任务对应的病人编号和实验编号
    fnum = ceil(idx / num_experiments);
    EXP_NUM = mod(idx-1, num_experiments) + 1;
    
    try
        % 加载当前病人的数据
        data = load(".mat");
        test_adjacency = data.(['N', num2str(fnum)]);
        fprintf('Worker %d 开始处理病人 %d, 实验 %d/%d\n', labindex, fnum, EXP_NUM, num_experiments);
        
        D = size(test_adjacency, 1);
        
        % 构建二进制网络
        test_net = zeros(D, D);
        test_net(test_adjacency ~= 0) = 1;
        
        %% 构建约束（连通分量）
        Cons = CONS(test_net);
        Cons(all(Cons == 0, 2), :) = [];
        cons = Cons;
        Cnum = size(cons, 1);
        g = cell(Cnum, 1);
        for h = 1:Cnum
            g{h} = find(cons(h, :) == 1);
        end
        
        %% 计算每个维度的度
        Dimension = eye(D, D);
        CV_num = Calcons(D, Cnum, g, Dimension);
        D_score = abs(CV_num - Cnum);
        
        %% 初始化种群（每个实验独立初始化）
        [P1, iv1, sv1, mask1, ~] = Init_Main_Population(popnum, D, S, test_adjacency, @Task_Function1);
        [P2, iv2, sv2, mask2, ~] = Init_Main_Population1(popnum, D, S, test_adjacency, @Task_Function2);
        [P3, iv3, sv3, mask3, ~] = Init_Main_Population1(popnum, D, S, test_adjacency, @Task_Function3);
        [P4, iv4, sv4, mask4, ~] = Init_Main_Population(popnum, D, S, test_adjacency, @Task_Function4);
        [P5, iv5, sv5, mask5, ~] = Init_Main_Population1(popnum, D, S, test_adjacency, @Task_Function5);
        
        CalNum = 0;
        
        %% 优化循环
        while CalNum < Max_CalNum
            % 计算目标函数值
            [~, Functionvalue1, calnum1] = Task_Function1(mask1, test_adjacency);
            [~, Functionvalue2, calnum2] = Task_Function2(mask2, test_adjacency);
            [~, Functionvalue3, calnum3] = Task_Function3(mask3, test_adjacency);
            CalNum = CalNum + calnum1 + calnum2 + calnum3;
            
            [mask1, tt1] = FIX1(mask1, Functionvalue1, g, D, D_score, test_adjacency);
            [Functionvalue1, calnum_fix] = Calfunctionvalue_afterfix(mask1, test_adjacency, tt1, Functionvalue1);
            CalNum = CalNum + calnum_fix;
            
            [~, Functionvalue4, calnum4] = Task_Function4(mask4, test_adjacency);
            [~, Functionvalue5, calnum5] = Task_Function5(mask5, test_adjacency);
            CalNum = CalNum + calnum4 + calnum5;
            
            [mask4, tt4] = FIX1(mask4, Functionvalue4, g, D, D_score, test_adjacency);
            [Functionvalue4, calnum_fix4] = Calfunctionvalue_afterfix(mask4, test_adjacency, tt4, Functionvalue4);
            CalNum = CalNum + calnum_fix4;
            
            if CalNum >= Max_CalNum, break; end
            
            pop_all = {mask1, mask2, mask3, mask4, mask5};
            
            % 非支配排序（任务1组）
            molecular = max(Functionvalue2, 0.001);
            denominator = max(Functionvalue3, 0.001);
            molecular(isnan(molecular)) = 0.001;
            denominator(isnan(denominator)) = 0.001;
            total = Functionvalue1(:,2);
            obj1 = [molecular, denominator, total];
            [FrontNo1, SpCrowdDis1] = m_non_domination_scd_sort3(obj1);
            
            % 非支配排序（任务4组）
            molecular1 = -max(Functionvalue5, 0.001);
            molecular1(isnan(molecular1)) = 0.001;
            total1 = Functionvalue4(:,2);
            obj2 = [molecular1, total1];
            [FrontNo2, SpCrowdDis2] = m_non_domination_scd_sort3(obj2);
            
            % 选择父代
            MatingPool1 = TournamentSelection_hamming1(popnum/2, popnum, P1, FrontNo1, SpCrowdDis1);
            MatingPool2 = TournamentSelection_hamming1(popnum/2, popnum, P4, FrontNo2, SpCrowdDis2);
            
            N = size(P1, 1);
            lb = zeros(1, D); ub = ones(1, D);
            sparsity1 = sum(mask1)/D;
            sparsity4 = sum(mask4)/D;
            
            % 产生子代
            Offspring1 = gai1(mask1, P1, MatingPool1, FrontNo1, SpCrowdDis1, lb, ub, sparsity1, pop_all, iv1, sv1, iv4, sv4, 1);
            Offspring4 = gai1(mask4, P4, MatingPool2, FrontNo2, SpCrowdDis2, lb, ub, sparsity4, pop_all, iv1, sv1, iv4, sv4, 4);
            [Offspring2, Offspring3, Offspring5] = generateAuxiliaryOffspring330(P2, P3, P5, iv1, sv1, iv4, sv4, D);
            
            % 计算子代目标函数
            [~, Functionvalue1_off, calnum_off1] = Task_Function1(Offspring1, test_adjacency);
            [~, Functionvalue2_off, calnum_off2] = Task_Function21(Offspring2.mask, test_adjacency);
            [~, Functionvalue3_off, calnum_off3] = Task_Function31(Offspring3.mask, test_adjacency);
            CalNum = CalNum + calnum_off1 + calnum_off2 + calnum_off3;
            
            [Offspring1, tt1_off] = FIX1(Offspring1, Functionvalue1_off, g, D, D_score, test_adjacency);
            [Functionvalue1_off, calnum_fix_off] = Calfunctionvalue_afterfix(Offspring1, test_adjacency, tt1_off, Functionvalue1_off);
            CalNum = CalNum + calnum_fix_off;
            
            [~, Functionvalue4_off, calnum_off4] = Task_Function41(Offspring4, test_adjacency);
            [~, Functionvalue5_off, calnum_off5] = Task_Function51(Offspring5.mask, test_adjacency);
            CalNum = CalNum + calnum_off4 + calnum_off5;
            
            [Offspring4, tt4_off] = FIX1(Offspring4, Functionvalue4_off, g, D, D_score, test_adjacency);
            [Functionvalue4_off, calnum_fix4_off] = Calfunctionvalue_afterfix(Offspring4, test_adjacency, tt4_off, Functionvalue4_off);
            CalNum = CalNum + calnum_fix4_off;
            
            if CalNum >= Max_CalNum, break; end
            
            % 环境选择
            Pop_new1 = [P1; Offspring1];
            Pop_new2 = [P2; Offspring2.mask];
            Pop_new3 = [P3; Offspring3.mask];
            Pop_new4 = [P4; Offspring4];
            Pop_new5 = [P5; Offspring5.mask];
            
            [P1, ~, ~] = SparseEA_EnvironmentalSelection1(Pop_new1, Functionvalue1_off(:,2), N);
            [P4, ~, ~] = SparseEA_EnvironmentalSelection1(Pop_new4, Functionvalue4_off(:,2), N);
            [P2, ~, ~] = SparseEA_EnvironmentalSelection1(Pop_new2, Functionvalue2_off, N);
            [P3, ~, ~] = SparseEA_EnvironmentalSelection1(Pop_new3, Functionvalue3_off, N);
            [P5, ~, ~] = SparseEA_EnvironmentalSelection1(Pop_new5, Functionvalue5_off, N);
            
            % 知识迁移
            rho = round(0.1 * N);
            P_cell = {P1, P2, P3, P4, P5};
            OffMask = P_cell;
            OffDec = createOffDec(P_cell);
            iv_cell = {iv1, iv2, iv3, iv4, iv5};
            sv_cell = {sv1, sv2, sv3, sv4, sv5};
            
            [P_cell, ~, ~] = SKT_final330(P_cell, OffMask, OffDec, iv_cell, sv_cell, rho, D, test_adjacency, N);
            P1 = P_cell{1}; P2 = P_cell{2}; P3 = P_cell{3}; P4 = P_cell{4}; P5 = P_cell{5};
            mask1 = P1; mask2 = P2; mask3 = P3; mask4 = P4; mask5 = P5;
        end
        
        % 计算最终结果
        [~, F1_final, ~] = Task_Function1(P1, test_adjacency);
        [~, F4_final, ~] = Task_Function41(P4, test_adjacency);
        
        matrix1 = [F1_final(:,1), F1_final(:,2)];
        matrix2 = [F4_final(:,1), F4_final(:,2)];
        matrix3 = P1;
        
        % 保存结果（每个实验独立保存）
        save_path = 'D:\自适应迁移降维lusc节点熵';
        subdirs = {'预警分数', '熵', '种群'};
        for i = 1:3
            full_sub = fullfile(save_path, subdirs{i});
            if ~exist(full_sub, 'dir')
                mkdir(full_sub);
            end
        end
        
        % 使用parsave保存（注意：parfor内调用parsave是允许的，只要每个迭代写不同文件）
        parsave(fullfile(save_path, '预警分数', sprintf('matrix1_f%d_e%d.mat', fnum, EXP_NUM)), 'matrix1', matrix1);
        parsave(fullfile(save_path, '熵', sprintf('matrix2_f%d_e%d.mat', fnum, EXP_NUM)), 'matrix2', matrix2);
        parsave(fullfile(save_path, '种群', sprintf('matrix3_f%d_e%d.mat', fnum, EXP_NUM)), 'matrix3', matrix3);
        
        fprintf('病人 %d 实验 %d 完成并保存\n', fnum, EXP_NUM);
        
    catch ME
        fprintf('处理病人 %d 实验 %d 时出错: %s\n', fnum, EXP_NUM, ME.message);
        continue;
    end
end

delete(gcp('nocreate'));
end

%% 辅助函数：在parfor中安全保存变量
function parsave(filename, varname, varvalue)
    eval([varname ' = varvalue;']);
    save(filename, varname);
end