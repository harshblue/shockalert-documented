rm(list=ls())
load("results/concomitant.combined.results2.rdata")

model.index = 3

predictions.all.glm = lapply(preds.glm[model.index], function(x) x@predictions[[1]])
predictions.all.glm = do.call(c,predictions.all.glm)

labels.all.glm = lapply(preds.glm[model.index], function(x) x@labels[[1]])
labels.all.glm = do.call(c,labels.all.glm)

deciles.glm = quantile(predictions.all.glm[labels.all.glm==2],seq(from=0,to=1,by=0.1))
ppvs.glm = mapply(function(a,b){
    sum(labels.all.glm[predictions.all.glm<=b&predictions.all.glm>a]==2)/sum(predictions.all.glm<=b&predictions.all.glm>a)
},deciles.glm[-length(deciles.glm)],deciles.glm[-1])


predictions.all.xgb = lapply(preds.xgb[model.index], function(x) x@predictions[[1]])
predictions.all.xgb = do.call(c,predictions.all.xgb)

labels.all.xgb = lapply(preds.xgb[model.index], function(x) x@labels[[1]])
labels.all.xgb = do.call(c,labels.all.xgb)

deciles.xgb = quantile(predictions.all.xgb[labels.all.xgb==2],seq(from=0,to=1,by=0.1))
ppvs.xgb = mapply(function(a,b){
    sum(labels.all.xgb[predictions.all.xgb<=b&predictions.all.xgb>a]==2)/sum(predictions.all.xgb<=b&predictions.all.xgb>a)
},deciles.xgb[-length(deciles.xgb)],deciles.xgb[-1])

load("results/results.3layer.gru.concomitant.subset3.rdata")

predictions.all.rnn = pred@predictions[[1]]
labels.all.rnn = pred@labels[[1]]
deciles.rnn = quantile(predictions.all.rnn[labels.all.rnn==1],seq(from=0,to=1,by=0.1))

ppvs.rnn = mapply(function(a,b){
    sum(labels.all.rnn[predictions.all.rnn<=b&predictions.all.rnn>a]==1)/sum(predictions.all.rnn<=b&predictions.all.rnn>a)
},deciles.rnn[-length(deciles.rnn)],deciles.rnn[-1])

data = data.frame(percentile=rep(0:9*10,3),ppv=c(ppvs.glm,ppvs.xgb,ppvs.rnn),model=c(rep("glm",10),rep("xgb",10),rep("rnn",10)))

png("figures/patient_ppv.png",width=800,height=600)
ggplot(data,aes(x=percentile,y=ppv,color=factor(model,levels=c("glm","xgb","rnn"))))+geom_line(size=1)+ylim(0,1)+
    scale_x_continuous(breaks=seq(from=0,to=90,by=10))+
    xlab("Percentile")+ylab("PPV")+
    labs(color="Model")+
    scale_color_manual(breaks=c("glm","xgb","rnn"),labels=c("GLM","XGBoost","RNN"),values=c("black","red","green"))+
    theme(axis.text=element_text(size=20),
          axis.title=element_text(size=24),
          legend.title=element_text(size=24),
          legend.text=element_text(size=20),
          legend.justification =c(1,0),
          legend.position=c(1,0),
          legend.box.margin=margin(c(10,10,10,10)))
dev.off()