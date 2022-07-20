(* ::Package:: *)

BeginPackage["SWT`"];

<<sneg`sneg`;

MatrixElementOverListsProj[Op_,PList_,QList_]:=
	Module[{PProj,QProj,bl},
		If[Not[PossibleZeroQ[Op]],
		   PProj=PList/.{ket_->nc[ket,conj[ket]]};
		   QProj=QList/.{ket_->nc[ket,conj[ket]]};
		   bl = Map[nc[#,QProj]&,Op];
		   Return[Total[Outer[nc[#1,#2]&,PProj,bl],2]],
		   Return[0]
		];
	]
OffDiagSuperOp[Op_,PList_,QList_]:=Module[{},
	Return[MatrixElementOverListsProj[Op,PList,QList]
			+MatrixElementOverListsProj[Op,QList,PList]]
	]
DiagSuperOp[Op_,PList_,QList_]:=Module[{},
	Return[MatrixElementOverListsProj[Op,PList,PList]
	+MatrixElementOverListsProj[Op,QList,QList]]
	]
LSuperOperator[Op_,H0_,PList_,QList_]:=
	Module[{PProjList,QProjList,PLength,QLength,
			 result,Eni,Enj,OffDiagOp,Pidx,Qidx},
			PProjList=PList/.{ket_->nc[ket,conj[ket]]};
			QProjList=QList/.{ket_->nc[ket,conj[ket]]};
			PLength=Length[PList];
			QLength=Length[QList];
			result=0;
			OffDiagOp=OffDiagSuperOp[Op,PList,QList];
			For[Pidx=1,Pidx<=PLength,Pidx++,
				For[Qidx=1,Qidx<=QLength,Qidx++,
					Eni=nc[conj[PList[[Pidx]]],H0,PList[[Pidx]]];
					Enj=nc[conj[QList[[Qidx]]],H0,QList[[Qidx]]];
					result+=Map[nc[PProjList[[Pidx]],#,QProjList[[Qidx]]]
						/(Eni-Enj)&,OffDiagOp];
					result+=Map[nc[QProjList[[Qidx]],#,PProjList[[Pidx]]]
						/(Enj-Eni)&,OffDiagOp];
				];
			];
			Return[result]
	]
GenerateNextPartition[PrevVec_]:=
	Module[{NN,VecLength,NextVec,idx,updateidx},
		NN=Total[PrevVec];
		VecLength=Length[PrevVec];
		updateidx=0;
		For[idx=VecLength-1,idx>=1,idx=idx-1,
			If[PrevVec[[idx]]!=0,
				updateidx=idx;
				Break[];
			];
		];
		NextVec=Table[0,VecLength];
		NextVec[[1;;updateidx-1]]=PrevVec[[1;;updateidx-1]];
		NextVec[[updateidx]]=PrevVec[[updateidx]]-1;
		NextVec[[updateidx+1]]=NN-Total[NextVec[[1;;updateidx]]];
		Return[NextVec]
	]
GenerateAllPartitions[k_,m_]:=
	Module[{InitialVec,AllPartitions,PrevVec,NextVec},
		InitialVec=Table[0,k];
		InitialVec[[1]]=m;
		AllPartitions={InitialVec};
		PrevVec=InitialVec;
		While[PrevVec[[k]]!=m,
			NextVec=GenerateNextPartition[PrevVec];
			AllPartitions=Append[AllPartitions,NextVec];
			PrevVec=NextVec;
		];
	Return[AllPartitions]
	]
amCoeff[m_]:=(2^m BernoulliB[m])/m!
b2nminus1Coeff[n_]:=(2*(2^(2*n)-1)BernoulliB[2*n])/(2*n)!
ComputeEffectiveHamiltonian[n_,H0_,VOp_,PList_,QList_]:=
	Module[{result,OffDVOp,gensum,j},
		If[n==0,
			Return[MatrixElementOverListsProj[H0,PList,PList]],
			If[n==1,
				Return[MatrixElementOverListsProj[VOp,PList,PList]],
				result=0;
				OffDVOp=OffDiagSuperOp[VOp,PList,QList];
				For[j=1,2*j<=n,j++,
					gensum=GeneratorSum[H0,VOp,OffDVOp,2*j-1,n-1,PList,QList];
					result+=b2nminus1Coeff[j]
							*MatrixElementOverListsProj[gensum,PList,PList];
				];
				Return[result]
			];
		];
	]
GeneratorSum[H0_,VOp_,Seed_,k_,m_,PList_,QList_]:=
	Module[{AllPartitions,NumPartitions,GenList,NestedCommResult,
			result,genidx,partidx,CurrentPartition,Sgenidx},
		AllPartitions=GenerateAllPartitions[k,m];
		NumPartitions=Length[AllPartitions];
		result=0;
		For[partidx=1,partidx<=NumPartitions,partidx++,
			GenList={};
			CurrentPartition=AllPartitions[[partidx]];
			If[Not[AnyTrue[CurrentPartition,PossibleZeroQ]],
				For[genidx=1,genidx<=k,genidx++,
					Sgenidx=ComputeGenerator[CurrentPartition[[genidx]],
												H0,VOp,PList,QList];
					GenList=Append[GenList,Sgenidx]
				];
				NestedCommResult=Seed;
				For[genidx=k,genidx>=1,genidx=genidx-1,
					NestedCommResult=commutator[GenList[[genidx]],NestedCommResult];
				];
				result+=NestedCommResult;
			];
		];
		Return[result]
	]
ComputeGenerator[n_,H0_,V_,PList_,QList_]:=
	Module[{S1,S2,Snm1,Sn,Vd,Vod,j,GenSum},
		If[n==0,
		Return[0],
			If[n==1,
				Return[LSuperOperator[V,H0,PList,QList]],
				If[n==2,
					S1=ComputeGenerator[1,H0,V,PList,QList];
					Vd=DiagSuperOp[V,PList,QList];
					S2=-LSuperOperator[commutator[Vd,S1],H0,PList,QList];
					Return[S2],
					(* n>=3 *)
					Vd=DiagSuperOp[V,PList,QList];
					Vod=OffDiagSuperOp[V,PList,QList];
					Snm1=ComputeGenerator[n-1,H0,V,PList,QList];
					Sn=-LSuperOperator[commutator[Vd,Snm1], H0,PList,QList];
					For[j=1,2*j<=n-1,j++,
						GenSum = GeneratorSum[H0,V,Vod,2*j,n-1,PList,QList];
						Sn+=amCoeff[2*j]*LSuperOperator[GenSum,H0,PList,QList];
					];
					Return[Sn]
				];
			];
		];
	]
	
EndPackage[];
