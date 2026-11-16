function [offspring2, offspring3, offspring5, offspring6] = generateAuxiliaryOffspring(mask2, mask3,mask5,mask6 ,iv1, sv1, iv4, sv4, D)
    % 辅助任务2子代（分子最大化任务）- 使用任务1的参数
    offspring2.mask = mask2;
    offspring2.sparsity = sum(offspring2.mask)/D;
    
    % 从主任务1迁移知识
    if offspring2.sparsity < sv1
        Num = floor(D * (sv1 - offspring2.sparsity));
        for j = 1:Num
            [m, n] = selectImportantVariables(iv1, offspring2.mask);
            % 辅助任务特殊处理：分子需要最大化，选择iv较小的变量
            offspring2.mask(m) = 1;
        end
    end
    
    % 辅助任务3子代（分母最小化任务）- 使用任务1的参数
    offspring3.mask = mask3;
    offspring3.sparsity = sum(offspring3.mask)/D;
    
    if offspring3.sparsity < sv1
        Num = floor(D * (sv1 - offspring3.sparsity));
        for j = 1:Num
            [m, n] = selectImportantVariables(iv1, offspring3.mask);
            % 分母任务特殊处理：选择iv较大的变量
            offspring3.mask(n) = 1;
        end
    end
    
    % 辅助任务5子代（节点熵最大化）- 使用任务4的参数
    offspring5.mask = mask5;
    offspring5.sparsity = sum(offspring5.mask)/D;

    if offspring5.sparsity < sv4
        Num = floor(D * (sv4 - offspring5.sparsity));
        for j = 1:Num
            [m, n] = selectImportantVariables(iv4, offspring5.mask);
            % 熵最大化任务：倾向于选择iv中等的变量
            if abs(iv4(m)-0.5) < abs(iv4(n)-0.5)
                offspring5.mask(m) = 1;
            else
                offspring5.mask(n) = 1;
            end
        end
    end
    % 
    % % 辅助任务6子代（边熵最大化）- 使用任务4的参数
    offspring6.mask = mask6;
    offspring6.sparsity = sum(offspring6.mask)/D;

    if offspring6.sparsity < sv4
        Num = floor(D * (sv4 - offspring6.sparsity));
        for j = 1:Num
            [m, n] = selectImportantVariables(iv4, offspring6.mask);
            % 边熵任务：考虑变量间的关联性
            if checkEdgeAssociation(m, n)
                offspring6.mask(m) = 1;
                offspring6.mask(n) = 1;
            else
                offspring6.mask(m) = 1;
            end
        end
    end
end
