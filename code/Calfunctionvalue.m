function [functionvalue,Functionvalue,W_g,W,T,M,N,B2,S] = Calfunctionvalue(pop,test_adjacency)  %（label，pop，uncons）
Functionvalue=zeros(size(pop,1),4);  %初始化为0，只有两列，分别用于存储基因数目和最终的预警分数。
functionvalue=zeros(size(pop,1),6);  %同样大小的矩阵，用于存储计算过程的中间值，共五列
% calnum=0;
for i=1:size(pop,1)
    Functionvalue(i,1)=sum(pop(i,:)); %这一步求得目标是选中得节点数目
    %计算内部矩阵
    a=find(pop(i,:)==1);
    matrix=test_adjacency(a,:);
     inmatrix=matrix(:,a);
    genin=nonzeros(inmatrix);
    
    functionvalue(i,1)=abs(mean(genin));
    functionvalue(i,2)=std(genin);
    
    %计算外部矩阵
    gen=nonzeros(matrix);
    genout=setdiff(gen,genin);
    
    functionvalue(i,3)=abs(mean(genout));
    functionvalue(i,4)=functionvalue(i,1)*functionvalue(i,2); %这一步是计算预警分数的
    functionvalue(i,5)=functionvalue(i,1)*functionvalue(i,2)/functionvalue(i,3); %这个5是计算总预警分数的，还用吗？
    functionvalue(i,6)=sum(pop(i,:));
%     calnum=i;
    Functionvalue(:,2)= -round(functionvalue(:,3)*100)/100;
    Functionvalue(:,3)= -round(functionvalue(:,4)*100)/100;
    Functionvalue(:,4)= -round(functionvalue(:,5)*100)/100;
end
    %  预警分数的下层分解（分子（标准差乘组内分子间波动）和分母（组内外分子间波动））、分子越大越好，分母越好越好
    N = size(pop, 1);                            % 数量选择分母的或者分子的都可以
    M = size(Functionvalue(:,2), 1);                           % 每个权重向量的维度（预警分数的分子和分母）
    W = lhsdesign(N, M);        %把UniformPoint换成lhsdesign，回头再换回来
    N = size(W, 1);  
    W(1, :)=Functionvalue(:,3) ;           % 预警分数分子
    W(2, :)=Functionvalue(:,2) ; 
    %  上层权重向量分解 （节点和总预警分数）
    S=2 * ceil(sqrt(N)); 
    M1 = size(Functionvalue(:,1), 1);
    W_g= lhsdesign(S,M1); 
    S=size(W_g,1);
    W_g(1, :)=Functionvalue(:,1);          % 节点
    W_g(2, :)=Functionvalue(:,4); 

if  M1>=2
    W_g=lhsdesign(50*N,M1);
    [~,W_g]=kmeans(W_g,S,'Distance','cosine','MaxIter',1000);
end
S=2;
% adjust upper-level weight vectors
%DNB
dist=pdist2(W_g,W,'cosine');  %  余弦距离衡量的是两个向量之间的夹角，值越小表示夹角越小，向量越相似。
                              %  dist：结果是一个矩阵，其中第 (i, j) 个元素表示 W_g 中第 i 行向量与 W 中第 j 行向量之间的余弦距离。
[~,Io]=min(dist,[],2); % 对于每个上层权重向量 W_g，找到与其最近的下层权重向量 W 
T=max(histcounts(Io, 1:S+1)); % T：表示每个组中分配的底层权重向量的最大数量 
for k=1:S 
Ii=find(Io==k); 
if length(Ii)<T %正常都是T个，如果不满足就把T中剩余的补成相关的向量 
try % use the mink function introduced in matlab2017
[~,Ii]=mink(dist(k,:),T); 
catch % use the sort method if mink is not available
[~,Ii]=sort(dist(k,:)); %sort 函数用于对数组或矩阵中的元素进行排序
Ii=Ii(1:T); 
end
end
B2(k,:)=Ii;
% % Variant 1: no adjustment to group centres
W_g(k,:)=mean(W(Ii,:),1); %计算分配给第 k 个组的底层权重向量的均值，并将其作为新的组中心
end
end