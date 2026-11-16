function leader_mask = build_leader_mask(S, OffMask, D)
    % 初始化二进制领导向量
    leader_mask = false(1, D);
    
    % 遍历源任务索引集合
    for s_idx = 1:length(S)
        s = S(s_idx);
        if ~isempty(OffMask{s})
            % 聚合当前任务所有个体的mask
            for j = 1:length(OffMask{s})
                if ~isempty(OffMask{s}(j))
                    leader_mask = leader_mask | OffMask{s}(j);
                end
            end
        end
    end
    
    % 异常处理：无有效mask时随机初始化
     if any(leader_mask)
        rand_indices = randperm(D, max(1, round(D*0.1)));
        leader_mask(rand_indices) = true;
    end
end
