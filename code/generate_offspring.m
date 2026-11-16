function O = generate_offspring(task_idx, S, OffDec, OffMask, leader_mask, current_iv, current_sv, rho, D)
    % 初始化后代
    O.dec = zeros(1, D);
    O.mask = false(1, D);
    
    % 获取当前目标任务父代个体p
    if ~isempty(OffDec{task_idx}) && ~isempty(OffMask{task_idx})
        valid_size = size(OffDec{task_idx}, 1);
        p_idx = randi(valid_size);
        O.dec = OffDec{task_idx}(p_idx, :);
        O.mask = OffMask{task_idx}(p_idx, :);
    end
    
    % 随机选择一个源任务个体q（从源任务集合S中随机选择）
    if ~isempty(S)
        s_idx = S(randi(length(S)));
        if ~isempty(OffMask{s_idx}) && ~isempty(OffDec{s_idx})
            valid_size = size(OffMask{s_idx}, 1);
            q_idx = randi(valid_size);
            q_mask = OffMask{s_idx}(q_idx, :);
        else
            q_mask = false(1, D);
        end
    else
        q_mask = false(1, D);
    end
    
    % 计算当前稀疏度和目标稀疏度
    current_ones = sum(O.mask);
    target_ones = round(current_sv * D);
    
    % 根据稀疏度关系执行不同的交叉操作
    if current_ones < target_ones
        % 情况1：需要增加非零变量（从leader_mask中选择）
        needed = target_ones - current_ones;
        candidate_positions = find(leader_mask & ~O.mask);
        
        if ~isempty(candidate_positions)
            % 根据变量重要性排序选择
            [~, sorted_idx] = sort(current_iv(candidate_positions), 'descend');
            selected = candidate_positions(sorted_idx(1:min(needed, length(candidate_positions))));
            O.mask(selected) = true;
            % 为新激活的变量生成随机值（在[0,1]范围内）
            O.dec(selected) = rand(1, length(selected));
        end
        
    else
        % 情况2：需要减少或保持非零变量（从p∩q中选择保留）
        excess = current_ones - target_ones;
        if excess > 0
            % 找出p和q共有的非零位置
            common_positions = find(O.mask & q_mask);
            
            if ~isempty(common_positions)
                % 根据变量重要性排序，保留重要的变量
                [~, sorted_idx] = sort(current_iv(common_positions), 'descend');
                keep_positions = common_positions(sorted_idx(1:min(length(common_positions), target_ones)));
                
                % 重置mask，只保留选择的变量
                O.mask(:) = false;
                O.mask(keep_positions) = true;
                
                % 将未保留的变量dec置零
                O.dec(~O.mask) = 0;
            else
                % 如果没有共同位置，随机减少
                one_positions = find(O.mask);
                [~, sorted_idx] = sort(current_iv(one_positions), 'ascend');
                remove_positions = one_positions(sorted_idx(1:min(excess, length(one_positions))));
                O.mask(remove_positions) = false;
                O.dec(remove_positions) = 0;
            end
        end
    end
    
    % 变异操作：随机调整少量变量
    mutation_rate = 1 / D;
    for dim = 1:D
        if rand() < mutation_rate
            if O.mask(dim)
                % 以小概率关闭当前变量
                if rand() < 0.3
                    O.mask(dim) = false;
                    O.dec(dim) = 0;
                else
                    % 扰动当前值
                    O.dec(dim) = max(0, min(1, O.dec(dim) + randn() * 0.1));
                end
            else
                % 以小概率开启当前变量（优先选择leader_mask中的变量）
                if rand() < 0.1 && leader_mask(dim)
                    O.mask(dim) = true;
                    O.dec(dim) = rand();
                end
            end
        end
    end
    
    % 确保至少有一个非零变量
    if sum(O.mask) == 0
        % 优先选择leader_mask中标记的位置
        candidate_positions = find(leader_mask);
        if ~isempty(candidate_positions)
            pos = candidate_positions(randi(length(candidate_positions)));
        else
            pos = randi(D);
        end
        O.mask(pos) = true;
        O.dec(pos) = rand();
    end
    
    % 确保dec值在[0,1]范围内
    O.dec = max(0, min(1, O.dec));
end