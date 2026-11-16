function [pop1, tt] = FIX1(Population, Functionvalue, g, D, D_score, test_adjacency)
    % 找出目标值第二列为零的个体索引
    tt = find(Functionvalue(:,2) == 0);
    
    % 获取种群大小
    N = size(Population, 1);
    
    for i = 1:length(tt)
        idx = tt(i);
        max_attempts = 3;  % 最大尝试修复次数
        attempt = 0;
        fixed = false;
        
        while ~fixed && attempt < max_attempts
            % 找到当前个体激活的节点位置
            node_position = find(Population(idx,:) ~= 0);
            
            % 情况1：没有激活任何节点
            if isempty(node_position)
                % 生成新个体
                Population(idx,:) = creatpop(1, D, D_score, g);
                
            % 情况2：只激活了一个节点    
            elseif length(node_position) == 1
                selected_node = node_position;
                
                % 找到与选定节点相连的所有节点
                connected_nodes = find(test_adjacency(selected_node,:) ~= 0);
                
                % 排除已经激活的节点
                available_nodes = setdiff(connected_nodes, selected_node);
                
                if ~isempty(available_nodes)
                    % 选择评分最低的节点（最需要被激活的）
                    [~, min_idx] = min(D_score(available_nodes));
                    add_node = available_nodes(min_idx);
                    Population(idx, add_node) = 1;
                else
                    % 如果没有可用连接节点，随机添加一个高评分节点
                    [~, top_nodes] = sort(D_score, 'descend');
                    Population(idx, top_nodes(1)) = 1;
                end
                
            % 情况3：激活了多个节点
            else
                % 随机选择两个已激活节点进行比较
                pair = randperm(length(node_position), 2);
                node1 = node_position(pair(1));
                node2 = node_position(pair(2));
                
                % 选择连接性更好的节点（这里用评分作为代理）
                if D_score(node1) > D_score(node2)
                    selected_node = node1;
                else
                    selected_node = node2;
                end
                
                % 找到与选定节点相连的所有节点
                connected_nodes = find(test_adjacency(selected_node,:) ~= 0);
                
                % 排除已经激活的节点
                available_nodes = setdiff(connected_nodes, node_position);
                
                if ~isempty(available_nodes)
                    % 选择评分最低的可用节点
                    [~, min_idx] = min(D_score(available_nodes));
                    add_node = available_nodes(min_idx);
                    Population(idx, add_node) = 1;
                else
                    % 如果没有可用连接节点，添加一个中心节点
                    [~, center_node] = max(sum(test_adjacency, 2));
                    Population(idx, center_node) = 1;
                end
            end
            
            % 验证修复效果
            [~, temp_FV, ~] = Task_Function1(Population(idx,:), test_adjacency);
            if temp_FV(2) ~= 0
                fixed = true;
            else
                attempt = attempt + 1;
                % 最后一次尝试时强制添加多个节点
                if attempt == max_attempts
                    % 添加3个最高评分节点
                    [~, top_nodes] = sort(D_score, 'descend');
                    Population(idx, top_nodes(1:min(3, end))) = 1;
                end
            end
        end
        
        % 最终验证
        [~, final_FV, ~] = Task_Function1(Population(idx,:), test_adjacency);
        if final_FV(2) == 0
            % 极端情况处理：激活5个最高评分节点
            [~, top_nodes] = sort(D_score, 'descend');
            Population(idx,:) = 0;
            Population(idx, top_nodes(1:min(5, end))) = 1;
            warning('个体%d修复困难，已强制激活多个节点', idx);
        end
    end
    
    pop1 = Population;
    
    
    % 返回仍然为零的个体索引（理论上应该为空）
    tt = find(Functionvalue(:,2) == 0);
    
    % 最终保护：如果还有零值，用随机高评分个体替换
    if ~isempty(tt)
        for i = 1:length(tt)
            pop1(tt(i),:) = creatpop(1, D, D_score, g);
        end
        tt = find(Functionvalue(:,2) == 0);
    end
end