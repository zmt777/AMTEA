 function A_adjacent=CONS(test_Net)
        [z1,z2]=find(triu(test_Net)~=0);
        z=[z1,z2];
        NNN=length(test_Net);

        N1=NNN;
        [N2,~]=size(z);
        %calculate the adjacency matrix of bipartite graph
        A_adjacent=zeros(N2,N1);
        for i=1:N2

            A_adjacent(i,z(i,1))=1;
            A_adjacent(i,z(i,2))=1;
        end
 end