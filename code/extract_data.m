
% 假设O是1x6的cell数组，每个cell包含含dec和mask字段的struct数组
function all_data = extract_data(O)
    % 初始化存储容器
    all_dec = [];
    all_mask = [];
    
    % 遍历每个任务
    for task_idx = 1:6
        current_struct = O{task_idx};
        
        % 提取当前任务的所有dec数据（转换为double）
        task_dec = vertcat(current_struct.dec); % 垂直拼接所有行的dec
        all_dec = [all_dec; task_dec]; % 追加到总矩阵
        
        % 提取当前任务的所有mask数据（逻辑转double）
        task_mask = double(vertcat(current_struct.mask)); % 逻辑值转double
        all_mask = [all_mask; task_mask];
    end
    
    % 合并两种数据（可选）
    all_data = struct('dec_data', all_dec, 'mask_data', all_mask);
end
