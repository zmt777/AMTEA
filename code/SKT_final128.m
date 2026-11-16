function P= SKT_final128(P, OffMask, OffDec, iv, sv, rho, D, test_adjacency, N, knowledge_transfer)
    % 定义任务分组
    main_tasks = [1, 4];           % 主任务
    auxiliary_tasks_1 = [2, 3];    % 任务1的辅助任务
    auxiliary_tasks_4 = [5, 6];    % 任务4的辅助任务
    
    %% ============ 知识迁移参数 ============
    if ~exist('knowledge_transfer', 'var') || isempty(knowledge_transfer)
        knowledge_transfer = struct();
        knowledge_transfer.enable = false;
    else
        % 确保所有必要字段都存在
        if ~isfield(knowledge_transfer, 'enable')
            knowledge_transfer.enable = false;
        end
        if ~isfield(knowledge_transfer, 'warning_knowledge')
            knowledge_transfer.warning_knowledge = [];
        end
        if ~isfield(knowledge_transfer, 'entropy_knowledge')
            knowledge_transfer.entropy_knowledge = [];
        end
        if ~isfield(knowledge_transfer, 'adjacency')
            knowledge_transfer.adjacency = test_adjacency;
        end
    end
    
    %% 主迁移循环 - 两个阶段
    for migration_phase = 1:2
        if migration_phase == 1
            migration_type = 'main_aux_within_group';
            migration_strength = 0.8;
        elseif migration_phase == 2
            migration_type = 'knowledge_based_cross';
            migration_strength = 0.5;
        end
        
        fprintf('迁移阶段 %d: %s\n', migration_phase, migration_type);
        
        % 初始化O数组
        O = cell(1, 6);
        
        % 根据迁移类型执行迁移
        switch migration_type
            case 'main_aux_within_group'
                % 组内迁移
                O = execute_within_group_migration(P, OffMask, OffDec, iv, sv, rho, D, ...
                    main_tasks, auxiliary_tasks_1, auxiliary_tasks_4, knowledge_transfer, migration_strength);
                
            case 'knowledge_based_cross'
                % 基于知识的跨组迁移
                O = execute_knowledge_cross_migration(P, OffMask, OffDec, iv, sv, rho, D, ...
                    main_tasks, auxiliary_tasks_1, auxiliary_tasks_4, knowledge_transfer, migration_strength);
        end
        
        %% 处理生成的迁移解
        O = process_migration_solutions(O, D);
        
        %% 环境选择
        P = enhanced_environmental_selection(P, O, test_adjacency, N);
    end
    
    %% 计算最终的FrontNo
    [~, Functionvalue1, ~] = Task_Function1(P{1}, test_adjacency);
    [~, Functionvalue4, ~] = Task_Function4(P{4}, test_adjacency);
    
    % molecular = max(Functionvalue1(:, 2), 0.001);
    % denominator = max(Functionvalue1(:, 3), 0.001);
    % obj1 = [molecular, denominator, Functionvalue1(:, 2)];
    % [FrontNo1, ~] = m_non_domination_scd_sort3(obj1);
    % 
    % molecular1 = -max(Functionvalue4(:, 2), 0.001);
    % denominator1 = -max(Functionvalue4(:, 3), 0.001);
    % obj2 = [molecular1, denominator1, Functionvalue4(:, 2)];
    % [FrontNo4, ~] = m_non_domination_scd_sort3(obj2);
end

%% ============ 核心辅助函数 ============

%% 执行组内迁移
function O = execute_within_group_migration(P, OffMask, OffDec, iv, sv, rho, D, main_tasks, ...
    auxiliary_tasks_1, auxiliary_tasks_4, knowledge_transfer, migration_strength)
    
    O = cell(1, 6);
    
    % 任务1组的迁移 (任务1, 2, 3)
    for target_task = [1, 2, 3]
        [S, current_iv, current_sv] = get_task_group_params(target_task, iv, sv);
        
        if ~isempty(S)
            leader_mask = build_leader_mask(S, OffMask, D);
            
            % 生成子代（包含知识迁移）
            offspring = generate_offspring_with_knowledge(target_task, S, OffDec, OffMask, ...
                leader_mask, current_iv, current_sv, rho, D, knowledge_transfer, migration_strength);
            
            O{target_task} = offspring;
        end
    end
    
    % 任务4组的迁移 (任务4, 5, 6)
    for target_task = [4, 5, 6]
        [S, current_iv, current_sv] = get_task_group_params(target_task, iv, sv);
        
        if ~isempty(S)
            leader_mask = build_leader_mask(S, OffMask, D);
            
            % 生成子代（包含知识迁移）
            offspring = generate_offspring_with_knowledge(target_task, S, OffDec, OffMask, ...
                leader_mask, current_iv, current_sv, rho, D, knowledge_transfer, migration_strength);
            
            O{target_task} = offspring;
        end
    end
end

%% 执行基于知识的跨组迁移
function O = execute_knowledge_cross_migration(P, OffMask, OffDec, iv, sv, rho, D, main_tasks, ...
    auxiliary_tasks_1, auxiliary_tasks_4, knowledge_transfer, migration_strength)
    
    O = cell(1, 6);
    
    % 检查是否有可用的知识
    if ~knowledge_transfer.enable || ...
       (isempty(knowledge_transfer.warning_knowledge) && ...
        isempty(knowledge_transfer.entropy_knowledge))
        return;
    end
    
    % 预警→熵迁移
    if ~isempty(knowledge_transfer.warning_knowledge)
        % 从任务1迁移到任务4
        for target_task = [4, 5, 6]
            [S, current_iv, current_sv] = get_task_group_params(target_task, iv, sv);
            
            if ~isempty(S)
                % 使用预警知识增强迁移
                leader_mask = build_leader_mask_with_knowledge(S, OffMask, D, target_task, knowledge_transfer, 'warning');
                
                offspring = generate_knowledge_transfer_offspring(target_task, S, OffDec, OffMask, ...
                    leader_mask, current_iv, current_sv, rho, D, knowledge_transfer, migration_strength, 'warning');
                
                O{target_task} = offspring;
            end
        end
    end
    
    % 熵→预警迁移
    if ~isempty(knowledge_transfer.entropy_knowledge)
        % 从任务4迁移到任务1
        for target_task = [1, 2, 3]
            [S, current_iv, current_sv] = get_task_group_params(target_task, iv, sv);
            
            if ~isempty(S)
                % 使用熵知识增强迁移
                leader_mask = build_leader_mask_with_knowledge(S, OffMask, D, target_task, knowledge_transfer, 'entropy');
                
                offspring = generate_knowledge_transfer_offspring(target_task, S, OffDec, OffMask, ...
                    leader_mask, current_iv, current_sv, rho, D, knowledge_transfer, migration_strength, 'entropy');
                
                O{target_task} = offspring;
            end
        end
    end
end

%% 获取任务组参数
function [S, current_iv, current_sv] = get_task_group_params(target_task, iv, sv)
    % 根据任务ID获取参数
    if target_task == 1 || target_task == 2 || target_task == 3
        current_iv = iv{1};
        current_sv = sv{1};
        S = setdiff([1, 2, 3], target_task); % 同组其他任务
    elseif target_task == 4 || target_task == 5 || target_task == 6
        current_iv = iv{4};
        current_sv = sv{4};
        S = setdiff([4, 5, 6], target_task); % 同组其他任务
    else
        S = [];
        current_iv = [];
        current_sv = [];
    end
end

%% 构建领导者掩码
function leader_mask = build_leader_mask(S, OffMask, D)
    leader_mask = zeros(1, D);
    
    if isempty(S)
        return;
    end
    
    all_masks = [];
    for k = 1:length(S)
        s_idx = S(k);
        if s_idx > 0 && s_idx <= length(OffMask)
            mask_data = OffMask{s_idx};
            if ~isempty(mask_data)
                all_masks = [all_masks; mask_data];
            end
        end
    end
    
    if ~isempty(all_masks)
        leader_mask = mean(all_masks, 1);
        % 归一化
        leader_mask = min(max(leader_mask, 0), 1);
    end
end

%% 构建带知识的领导者掩码
function leader_mask = build_leader_mask_with_knowledge(S, OffMask, D, target_task, knowledge_transfer, knowledge_type)
    % 基础领导者掩码
    leader_mask = build_leader_mask(S, OffMask, D);
    
    % 知识增强
    if knowledge_transfer.enable
        switch knowledge_type
            case 'warning'
                if ~isempty(knowledge_transfer.warning_knowledge) && target_task >= 4
                    % 预警知识增强
                    warning_influence = get_knowledge_influence(D, knowledge_transfer.warning_knowledge);
                    leader_mask = leader_mask .* (1 + 0.3 * warning_influence);
                end
                
            case 'entropy'
                if ~isempty(knowledge_transfer.entropy_knowledge) && target_task <= 3
                    % 熵知识增强
                    entropy_influence = get_knowledge_influence(D, knowledge_transfer.entropy_knowledge);
                    leader_mask = leader_mask .* (1 + 0.3 * entropy_influence);
                end
        end
        
        % 归一化
        leader_mask = min(max(leader_mask, 0), 1);
    end
end

%% 生成带知识的子代（修复randperm错误）
function offspring = generate_offspring_with_knowledge(target_task, S, OffDec, OffMask, leader_mask, ...
    current_iv, current_sv, rho, D, knowledge_transfer, migration_strength)
    
    offspring = [];
    
    if isempty(S) || migration_strength <= 0
        return;
    end
    
    num_offspring = max(1, round(migration_strength * 5));
    
    for i = 1:num_offspring
        % 随机选择源个体
        source_idx = S(randi(length(S)));
        if source_idx <= length(OffDec) && source_idx <= length(OffMask)
            source_dec = OffDec{source_idx};
            source_mask = OffMask{source_idx};
            
            if ~isempty(source_dec) && ~isempty(source_mask)
                % 基础交叉操作
                child_mask = zeros(1, D);
                child_dec = zeros(1, D);
                
                for d = 1:D
                    if rand() < leader_mask(d)
                        child_mask(d) = source_mask(d);
                        child_dec(d) = source_dec(d);
                    else
                        if rand() < current_iv(d)
                            child_mask(d) = 1;
                            child_dec(d) = 1;
                        end
                    end
                end
                
                % 应用知识增强
                if knowledge_transfer.enable && rand() < 0.5
                    if target_task <= 3 && ~isempty(knowledge_transfer.entropy_knowledge)
                        % 预警任务：应用熵知识
                        child_mask = apply_entropy_knowledge(child_mask, knowledge_transfer.entropy_knowledge, D);
                    elseif target_task >= 4 && ~isempty(knowledge_transfer.warning_knowledge)
                        % 熵任务：应用预警知识
                        child_mask = apply_warning_knowledge(child_mask, knowledge_transfer.warning_knowledge, D);
                    end
                end
                
                % 更新数值解并应用稀疏约束
                child_dec = child_dec .* child_mask;
                child_mask = enforce_sparsity_constraint(child_mask, current_sv, D);
                child_dec = child_dec .* child_mask;
                
                % 存储子代
                offspring_struct = struct();
                offspring_struct.dec = child_dec;
                offspring_struct.mask = child_mask;
                offspring = [offspring, offspring_struct];
            end
        end
    end
end

%% 生成知识迁移子代（修复randperm错误）
function offspring = generate_knowledge_transfer_offspring(target_task, S, OffDec, OffMask, leader_mask, ...
    current_iv, current_sv, rho, D, knowledge_transfer, migration_strength, knowledge_type)
    
    offspring = [];
    
    if isempty(S) || migration_strength <= 0
        return;
    end
    
    num_offspring = max(1, round(migration_strength * 3));
    
    for i = 1:num_offspring
        child_mask = zeros(1, D);
        child_dec = zeros(1, D);
        
        % 基于知识生成子代
        if strcmp(knowledge_type, 'warning') && ~isempty(knowledge_transfer.warning_knowledge)
            % 从预警知识迁移
            child_mask = transfer_warning_knowledge(child_mask, knowledge_transfer.warning_knowledge, D);
            
        elseif strcmp(knowledge_type, 'entropy') && ~isempty(knowledge_transfer.entropy_knowledge)
            % 从熵知识迁移
            child_mask = transfer_entropy_knowledge(child_mask, knowledge_transfer.entropy_knowledge, D);
        end
        
        % 应用领导者掩码指导
        for d = 1:D
            if rand() < leader_mask(d) && child_mask(d) == 0
                if rand() < 0.5
                    child_mask(d) = 1;
                end
            end
        end
        
        % 应用稀疏约束
        child_mask = enforce_sparsity_constraint(child_mask, current_sv, D);
        child_dec = child_mask; % 二进制问题，掩码即数值
        
        % 存储子代
        offspring_struct = struct();
        offspring_struct.dec = child_dec;
        offspring_struct.mask = child_mask;
        offspring = [offspring, offspring_struct];
    end
end

%% 应用预警知识（修复randperm错误）
function mask = apply_warning_knowledge(mask, warning_knowledge, D)
    if isempty(warning_knowledge)
        return;
    end
    
    % 选择高质量的解
    if length(warning_knowledge) >= 1
        % 取前3个高质量解
        num_to_check = min(3, length(warning_knowledge));
        scores = zeros(1, num_to_check);
        for i = 1:num_to_check
            if isfield(warning_knowledge(i), 'warning_score')
                scores(i) = warning_knowledge(i).warning_score;
            end
        end
        
        if ~isempty(scores)
            [~, best_idx] = max(scores);
            if best_idx <= length(warning_knowledge) && isfield(warning_knowledge(best_idx), 'solution')
                best_solution = warning_knowledge(best_idx).solution;
                
                % 激活重要基因
                important_genes = find(best_solution);
                if ~isempty(important_genes)
                    num_to_activate = min(3, length(important_genes));
                    if num_to_activate > 0 && length(important_genes) >= num_to_activate
                        genes_to_activate = important_genes(randperm(length(important_genes), num_to_activate));
                        mask(genes_to_activate) = 1;
                    end
                end
            end
        end
    end
end

%% 应用熵知识（修复randperm错误）
function mask = apply_entropy_knowledge(mask, entropy_knowledge, D)
    if isempty(entropy_knowledge)
        return;
    end
    
    % 选择高质量的解
    if length(entropy_knowledge) >= 1
        % 取前3个高质量解
        num_to_check = min(3, length(entropy_knowledge));
        scores = zeros(1, num_to_check);
        for i = 1:num_to_check
            if isfield(entropy_knowledge(i), 'entropy_value')
                scores(i) = entropy_knowledge(i).entropy_value;
            end
        end
        
        if ~isempty(scores)
            [~, best_idx] = max(scores);
            if best_idx <= length(entropy_knowledge) && isfield(entropy_knowledge(best_idx), 'solution')
                best_solution = entropy_knowledge(best_idx).solution;
                
                % 激活模块核心基因
                selected_genes = find(best_solution);
                if length(selected_genes) >= 2
                    core_size = ceil(0.5 * length(selected_genes));
                    core_genes = selected_genes(1:min(core_size, length(selected_genes)));
                    mask(core_genes) = 1;
                end
            end
        end
    end
end

%% 迁移预警知识（修复randperm错误）
function mask = transfer_warning_knowledge(mask, warning_knowledge, D)
    if isempty(warning_knowledge)
        return;
    end
    
    % 随机选择一个高质量解
    available_idx = min(3, length(warning_knowledge));
    if available_idx > 0
        idx = randi(available_idx);
        if idx <= length(warning_knowledge) && isfield(warning_knowledge(idx), 'solution')
            solution = warning_knowledge(idx).solution;
            
            % 选择重要基因进行迁移
            important_genes = find(solution);
            if ~isempty(important_genes)
                num_to_migrate = min(2, length(important_genes));
                if num_to_migrate > 0 && length(important_genes) >= num_to_migrate
                    genes_to_migrate = important_genes(randperm(length(important_genes), num_to_migrate));
                    mask(genes_to_migrate) = 1;
                end
            end
        end
    end
end

%% 迁移熵知识（修复randperm错误）
function mask = transfer_entropy_knowledge(mask, entropy_knowledge, D)
    if isempty(entropy_knowledge)
        return;
    end
    
    % 随机选择一个高质量解
    available_idx = min(3, length(entropy_knowledge));
    if available_idx > 0
        idx = randi(available_idx);
        if idx <= length(entropy_knowledge) && isfield(entropy_knowledge(idx), 'solution')
            solution = entropy_knowledge(idx).solution;
            
            % 选择模块基因进行迁移
            selected_genes = find(solution);
            if length(selected_genes) >= 2
                num_to_migrate = min(2, length(selected_genes));
                if num_to_migrate > 0 && length(selected_genes) >= num_to_migrate
                    genes_to_migrate = selected_genes(randperm(length(selected_genes), num_to_migrate));
                    mask(genes_to_migrate) = 1;
                end
            end
        end
    end
end

%% 获取知识影响
function influence = get_knowledge_influence(D, knowledge)
    influence = zeros(1, D);
    
    if isempty(knowledge)
        return;
    end
    
    % 分析前3个知识
    num_to_analyze = min(3, length(knowledge));
    for i = 1:num_to_analyze
        if isfield(knowledge(i), 'solution')
            solution = knowledge(i).solution;
            if isfield(knowledge(i), 'warning_score')
                weight = knowledge(i).warning_score;
            elseif isfield(knowledge(i), 'entropy_value')
                weight = knowledge(i).entropy_value;
            else
                weight = 1;
            end
            
            influence = influence + weight * solution;
        end
    end
    
    % 归一化
    if any(influence)
        influence = influence / sum(influence);
    end
end

%% 稀疏度约束（完全修复版）
function mask = enforce_sparsity_constraint(mask, target_sparsity, D)
    % 确保输入都是标量
    current_count = sum(mask);
    target_count = round(target_sparsity * D);
    delta = target_count - current_count;
    
    % 确保 delta 是标量
    if ~isscalar(delta)
        if isempty(delta)
            delta = 0;
        else
            delta = delta(1);
        end
    end
    
    if delta > 0  % 需要增加激活的变量
        % 找出未激活的变量
        inactive_vars = find(~mask);
        if ~isempty(inactive_vars)
            % 计算要激活的数量
            num_to_activate = min(delta, length(inactive_vars));
            
            % 确保是标量
            if ~isscalar(num_to_activate)
                num_to_activate = num_to_activate(1);
            end
            
            % 转换为整数
            num_to_activate = round(double(num_to_activate));
            num_to_activate = max(0, num_to_activate);
            
            % 检查条件
            condition1 = (num_to_activate > 0);
            condition2 = (length(inactive_vars) >= num_to_activate);
            
            if condition1 && condition2
                idx = randperm(length(inactive_vars), num_to_activate);
                mask(inactive_vars(idx)) = true;
            end
        end
        
    elseif delta < 0  % 需要减少激活的变量
        % 找出已激活的变量
        active_vars = find(mask);
        if ~isempty(active_vars)
            % 计算要失活的数量
            num_to_deactivate = min(-delta, length(active_vars));
            
            % 确保是标量
            if ~isscalar(num_to_deactivate)
                num_to_deactivate = num_to_deactivate(1);
            end
            
            % 转换为整数
            num_to_deactivate = round(double(num_to_deactivate));
            num_to_deactivate = max(0, num_to_deactivate);
            
            % 检查条件
            condition1 = (num_to_deactivate > 0);
            condition2 = (length(active_vars) >= num_to_deactivate);
            
            if condition1 && condition2
                idx = randperm(length(active_vars), num_to_deactivate);
                mask(active_vars(idx)) = false;
            end
        end
    end
end

%% 辅助任务的稀疏性约束（修复版）
function mask = enforce_auxiliary_sparsity(mask, target_sparsity, D)
    % 确保辅助任务满足稀疏性约束
    % 输入:
    %   mask - 当前掩码
    %   target_sparsity - 目标稀疏度
    %   D - 维度
    % 输出:
    %   mask - 调整后的掩码
    
    if isempty(mask)
        return;
    end
    
    current_count = sum(mask);
    target_count = round(target_sparsity * D);
    delta = target_count - current_count;
    
    % 确保 delta 是标量
    if ~isscalar(delta)
        if isempty(delta)
            delta = 0;
        else
            delta = delta(1);
        end
    end
    
    if delta > 0
        % 需要增加基因
        inactive_vars = find(~mask);
        if ~isempty(inactive_vars)
            % 计算要激活的数量
            num_to_activate = min(delta, length(inactive_vars));
            
            % 确保是标量
            if ~isscalar(num_to_activate)
                num_to_activate = num_to_activate(1);
            end
            
            % 转换为整数
            num_to_activate = round(double(num_to_activate));
            num_to_activate = max(0, num_to_activate);
            
            % 检查条件
            if num_to_activate > 0 && length(inactive_vars) >= num_to_activate
                % 使用安全的随机选择方法
                perm = randperm(length(inactive_vars));
                selected = inactive_vars(perm(1:num_to_activate));
                mask(selected) = true;
            end
        end
        
    elseif delta < 0
        % 需要减少基因
        active_vars = find(mask);
        if ~isempty(active_vars)
            % 计算要失活的数量
            num_to_deactivate = min(-delta, length(active_vars));
            
            % 确保是标量
            if ~isscalar(num_to_deactivate)
                num_to_deactivate = num_to_deactivate(1);
            end
            
            % 转换为整数
            num_to_deactivate = round(double(num_to_deactivate));
            num_to_deactivate = max(0, num_to_deactivate);
            
            % 检查条件
            if num_to_deactivate > 0 && length(active_vars) >= num_to_deactivate
                % 使用安全的随机选择方法
                perm = randperm(length(active_vars));
                selected = active_vars(perm(1:num_to_deactivate));
                mask(selected) = false;
            end
        end
    end
end

%% 应用预警知识到辅助任务（修复版）
function mask = apply_warning_knowledge_to_auxiliary(mask, warning_knowledge, task_type)
    % 将预警知识应用到辅助任务中
    % 输入:
    %   mask - 当前掩码
    %   warning_knowledge - 预警知识库
    %   task_type - 任务类型 ('molecule_maximization' 或 'denominator_minimization')
    % 输出:
    %   mask - 应用知识后的掩码
    
    if isempty(warning_knowledge)
        return;
    end
    
    % 计算基因重要性
    D = length(mask);
    gene_importance = zeros(1, D);
    
    for i = 1:min(8, length(warning_knowledge))
        if isfield(warning_knowledge(i), 'solution')
            solution = warning_knowledge(i).solution;
            weight = 1;
            if isfield(warning_knowledge(i), 'warning_score')
                weight = warning_knowledge(i).warning_score;
            end
            
            if length(solution) == D
                gene_importance = gene_importance + weight * solution;
            end
        end
    end
    
    % 根据任务类型选择策略
    switch task_type
        case 'molecule_maximization'
            % 分子最大化任务：选择中等重要性基因
            non_zero = gene_importance(gene_importance > 0);
            if ~isempty(non_zero)
                median_importance = median(non_zero);
                candidate_genes = find(gene_importance >= median_importance * 0.5 & ...
                                      gene_importance <= median_importance * 1.5 & ...
                                      ~mask);
                
                if ~isempty(candidate_genes)
                    % 确保 num_to_add 是标量
                    num_to_add = min(2, length(candidate_genes));
                    if ~isscalar(num_to_add)
                        num_to_add = num_to_add(1);
                    end
                    
                    if num_to_add > 0 && length(candidate_genes) >= num_to_add
                        selected = candidate_genes(randperm(length(candidate_genes), num_to_add));
                        mask(selected) = true;
                    end
                end
            end
            
        case 'denominator_minimization'
            % 分母最小化任务：避免高重要性基因
            non_zero = gene_importance(gene_importance > 0);
            if ~isempty(non_zero)
                threshold = prctile(non_zero, 70);
                candidate_genes = find(gene_importance < threshold & ~mask);
                
                if ~isempty(candidate_genes)
                    % 确保 num_to_add 是标量
                    num_to_add = min(2, length(candidate_genes));
                    if ~isscalar(num_to_add)
                        num_to_add = num_to_add(1);
                    end
                    
                    if num_to_add > 0 && length(candidate_genes) >= num_to_add
                        selected = candidate_genes(randperm(length(candidate_genes), num_to_add));
                        mask(selected) = true;
                    end
                end
            end
    end
end
%% 处理迁移解
function O = process_migration_solutions(O, D)
    for task_idx = 1:6
        if ~isempty(O{task_idx})
            if isstruct(O{task_idx})  % 如果是结构体数组
                num_individuals = length(O{task_idx});
                current_dec = zeros(num_individuals, D);
                current_mask = zeros(num_individuals, D);
                
                for indiv_idx = 1:num_individuals
                    if isfield(O{task_idx}(indiv_idx), 'dec') && isfield(O{task_idx}(indiv_idx), 'mask')
                        current_dec(indiv_idx, :) = O{task_idx}(indiv_idx).dec;
                        current_mask(indiv_idx, :) = O{task_idx}(indiv_idx).mask;
                    else
                        % 如果是普通数组
                        if size(O{task_idx}, 1) >= indiv_idx
                            current_dec(indiv_idx, :) = O{task_idx}(indiv_idx, :);
                            current_mask(indiv_idx, :) = O{task_idx}(indiv_idx, :) > 0;
                        end
                    end
                end
                
                O{task_idx} = current_dec .* current_mask;
            else
                % 已经是矩阵格式
                O{task_idx} = O{task_idx} .* (O{task_idx} > 0);
            end
        else
            O{task_idx} = [];
        end
    end
end

%% 环境选择
function P = enhanced_environmental_selection(P, O, test_adjacency, N)
    % 合并种群和迁移解
    for task_idx = 1:6
        if ~isempty(O{task_idx}) && ~isempty(P{task_idx})
            P{task_idx} = [P{task_idx}; O{task_idx}];
        end
    end
    
    % 计算目标函数值
    if ~isempty(P{1})
        [~, Functionvalue1, ~] = Task_Function1(P{1}, test_adjacency);
    else
        Functionvalue1 = [];
    end
    
    if ~isempty(P{2})
        [~, Functionvalue2, ~] = Task_Function2(P{2}, test_adjacency);
    else
        Functionvalue2 = [];
    end
    
    if ~isempty(P{3})
        [~, Functionvalue3, ~] = Task_Function3(P{3}, test_adjacency);
    else
        Functionvalue3 = [];
    end
    
    if ~isempty(P{4})
        [~, Functionvalue4, ~] = Task_Function4(P{4}, test_adjacency);
    else
        Functionvalue4 = [];
    end
    
    if ~isempty(P{5})
        [~, Functionvalue5, ~] = Task_Function5(P{5}, test_adjacency);
    else
        Functionvalue5 = [];
    end
    
    if ~isempty(P{6})
        [~, Functionvalue6, ~] = Task_Function6(P{6}, test_adjacency);
    else
        Functionvalue6 = [];
    end
    
    % 环境选择
    if ~isempty(Functionvalue1) && ~isempty(P{1})
        [P{1}, ~, ~] = SparseEA_EnvironmentalSelection1(P{1}, Functionvalue1(:, 2), N);
    end
    
    if ~isempty(Functionvalue4) && ~isempty(P{4})
        [P{4}, ~, ~] = SparseEA_EnvironmentalSelection1(P{4}, Functionvalue4(:, 2), N);
    end
    
    if ~isempty(Functionvalue2) && ~isempty(P{2})
        [P{2}, ~, ~] = SparseEA_EnvironmentalSelection1(P{2}, Functionvalue2, N);
    end
    
    if ~isempty(Functionvalue3) && ~isempty(P{3})
        [P{3}, ~, ~] = SparseEA_EnvironmentalSelection1(P{3}, Functionvalue3, N);
    end
    
    if ~isempty(Functionvalue5) && ~isempty(P{5})
        [P{5}, ~, ~] = SparseEA_EnvironmentalSelection1(P{5}, Functionvalue5, N);
    end
    
    if ~isempty(Functionvalue6) && ~isempty(P{6})
        [P{6}, ~, ~] = SparseEA_EnvironmentalSelection1(P{6}, Functionvalue6, N);
    end
end