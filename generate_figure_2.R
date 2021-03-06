rm(list=ls())

library(ggplot2)
library(gridExtra)
library(lubridate)
library(pracma)

load("sirs.rdata")
load("infection.antibiotics.cultures.rdata")
clinical.data = readRDS("clinical.data.mimic.rds")
sofa.scores = readRDS("processed/sofa_scores.rds")
icustays = readRDS("icustays.rds")
is.adult = readRDS("is.adult.rds")

clinical.icustay.ids = sapply(clinical.data, function(x) x$icustay.id)

has.infection.abx = is.element(clinical.icustay.ids, infection.abx.icustays)
has.infection.cultures = is.element(clinical.icustay.ids, infection.culture.icustays)

# generate sepsis-3 labels
sepsis.labels = sapply(sofa.scores, function(x) rowSums(x[2:7])>=2)
has.sepsis = sapply(sepsis.labels, any)

shock.labels = mapply(function(x,y) x&y$lactate&y$vasopressors, sepsis.labels, sofa.scores)
has.shock = sapply(shock.labels, function(x) any(x,na.rm=T))

sepsis3.labels = mapply(function(a,b) {
    result = rep(0,length(a))
    result[a] = 1
    result[b] = 2
    return(result)
}, sepsis.labels, shock.labels)

# count number of changes
sepsis2.num.changes = sapply(sepsis2.labels, function(x) {
    x[x==2] = 1
    if (length(x)<=1) {
        return(0)
    } else {
        return(sum(x[-1]!=x[-length(x)]))
    }
})

fprintf("Sepsis 2 (mean/median): %f \t %f\n", mean(sepsis2.num.changes[is.adult]), median(sepsis2.num.changes[is.adult]))

sepsis3.num.changes = sapply(sepsis3.labels, function(x) {
    if (length(x)<=1) {
        return(0)
    } else {
        return(sum(x[-1]!=x[-length(x)]))
    }
})

fprintf("Sepsis 3 (mean/median): %f \t %f\n", mean(sepsis3.num.changes[is.adult]), median(sepsis3.num.changes[is.adult]))


# Each returns a list of length 3 of a vector of state dwell times
tic("Compute sepsis-3 dwell time distribution")
sepsis3.dwell.times = mapply(function(a,b) {
    nonsepsis=c()
    sepsis=c()
    shock=c()
    if (length(a)>1) {
        breaks = which(a[-1]!=a[-length(a)]) + 1
        if (length(breaks>0)) {
            starts = c(1,breaks)
            ends = c(breaks,length(a))
            labels = a[starts]
            durations = as.duration(b$timestamps[ends]-b$timestamps[starts])/dhours(1)
            nonsepsis = append(nonsepsis,durations[labels==0])
            sepsis = append(sepsis,durations[labels==1])
            shock = append(shock,durations[labels==2])
        } else {
            if (a[1]==0) {
                nonsepsis = append(nonsepsis,as.duration(b$timestamps[length(b$timestamps)]-b$timestamps[1])/dhours(1))
            } else if (a[1] == 1) {
                sepsis = append(sepsis,as.duration(b$timestamps[length(b$timestamps)]-b$timestamps[1])/dhours(1))
            } else {
                shock = append(shock,as.duration(b$timestamps[length(b$timestamps)]-b$timestamps[1])/dhours(1))
            }
        }
    }
    return(list(nonsepsis=nonsepsis,sepsis=sepsis,shock=shock))

}, sepsis3.labels, sofa.scores, SIMPLIFY=F)
toc()

sepsis3.nonsepsis.dwell = sapply(sepsis3.dwell.times, function(x) x$nonsepsis)
sepsis3.nonsepsis.dwell = do.call(c,sepsis3.nonsepsis.dwell)
sepsis3.nonsepsis.dwell = sepsis3.nonsepsis.dwell[sepsis3.nonsepsis.dwell>0]

sepsis3.sepsis.dwell = sapply(sepsis3.dwell.times, function(x) x$sepsis)
sepsis3.sepsis.dwell = do.call(c,sepsis3.sepsis.dwell)
sepsis3.sepsis.dwell = sepsis3.sepsis.dwell[sepsis3.sepsis.dwell>0]

sepsis3.shock.dwell = sapply(sepsis3.dwell.times, function(x) x$shock)
sepsis3.shock.dwell = do.call(c,sepsis3.shock.dwell)
sepsis3.shock.dwell = sepsis3.shock.dwell[sepsis3.shock.dwell>0]

sepsis3.dwell.data = data.frame(dwell=c(sepsis3.nonsepsis.dwell,sepsis3.sepsis.dwell,sepsis3.shock.dwell),state=c(rep("Nonsepsis",length(sepsis3.nonsepsis.dwell)),rep("Sepsis",length(sepsis3.sepsis.dwell)),rep("Shock",length(sepsis3.shock.dwell))))

png("figures/fig2d.png",width=800,height=600)
ggplot(sepsis3.dwell.data, aes(x=dwell,fill=factor(state,levels=c("Shock","Sepsis","Nonsepsis")))) + 
    geom_histogram(boundary=1,binwidth=15) + xlim(0,150) +
    xlab("Time (hours)") + ylab("Frequency (thousands)") + labs(fill="State") +
    ggtitle("Clinical State Dwell Times for Sepsis-3") +
    scale_y_continuous(labels = function(x) {x/1000})+
    theme(axis.title = element_text(size=24),
          axis.text = element_text(size=20),
          legend.title = element_text(size=24),
          legend.text = element_text(size=20),
          plot.title = element_text(size=28, hjust=0.5),
          legend.justification = c(1,1),
          legend.position = c(1,1),
          legend.box.margin = margin(c(10, 10, 10, 10)))
dev.off()

tic("Sepsis-2 dwell times")
sepsis2.dwell.times = mapply(function(a,b) {
    a[a==2] = 1
    a[a==3] = 2
    nonsepsis=c()
    sepsis=c()
    shock=c()
    if (length(a)>1) {
        breaks = which(a[-1]!=a[-length(a)]) + 1
        if (length(breaks>0)) {
            starts = c(1,breaks)
            ends = c(breaks,length(a))
            labels = a[starts]
            durations = as.duration(b[ends]-b[starts])/dhours(1)
            nonsepsis = append(nonsepsis,durations[labels==0])
            sepsis = append(sepsis,durations[labels==1])
            shock = append(shock,durations[labels==2])
        } else {
            if (a[1]==0) {
                nonsepsis = append(nonsepsis,as.duration(b[length(b)]-b[1])/dhours(1))
            } else if (a[1] == 1) {
                sepsis = append(sepsis,as.duration(b[length(b)]-b[1])/dhours(1))
            } else {
                shock = append(shock,as.duration(b[length(b)]-b[1])/dhours(1))
            }
        }
    }
    return(list(nonsepsis=nonsepsis,sepsis=sepsis,shock=shock))
}, sepsis2.labels, sepsis2.timestamps, SIMPLIFY=F)
toc()

sepsis2.nonsepsis.dwell = sapply(sepsis2.dwell.times, function(x) x$nonsepsis)
sepsis2.nonsepsis.dwell = do.call(c,sepsis2.nonsepsis.dwell)
sepsis2.nonsepsis.dwell = sepsis2.nonsepsis.dwell[sepsis2.nonsepsis.dwell>0]

sepsis2.sepsis.dwell = sapply(sepsis2.dwell.times, function(x) x$sepsis)
sepsis2.sepsis.dwell = do.call(c,sepsis2.sepsis.dwell)
sepsis2.sepsis.dwell = sepsis2.sepsis.dwell[sepsis2.sepsis.dwell>0]

sepsis2.shock.dwell = sapply(sepsis2.dwell.times, function(x) x$shock)
sepsis2.shock.dwell = do.call(c,sepsis2.shock.dwell)
sepsis2.shock.dwell = sepsis2.shock.dwell[sepsis2.shock.dwell>0]


sepsis2.dwell.data = data.frame(dwell=c(sepsis2.nonsepsis.dwell,sepsis2.sepsis.dwell,sepsis2.shock.dwell),state=c(rep("Nonsepsis",length(sepsis2.nonsepsis.dwell)),rep("Sepsis/Severe Sepsis",length(sepsis2.sepsis.dwell)),rep("Shock",length(sepsis2.shock.dwell))))

png("figures/fig2b.png",width=800,height=600)
ggplot(sepsis2.dwell.data, aes(x=dwell,fill=factor(state,levels=c("Shock","Sepsis/Severe Sepsis","Nonsepsis")))) + 
    geom_histogram(boundary=0,binwidth=1) + xlim(1,15) +
    xlab("Time (hours)") + ylab("Frequency (thousands)") + labs(fill="State") + 
    ggtitle("Clinical State Dwell Times for Sepsis-2") +
    scale_y_continuous(labels = function(x) x/1000) +
    theme(axis.title = element_text(size=24),
          axis.text = element_text(size=20),
          legend.title = element_text(size=24),
          legend.text = element_text(size=20),
          plot.title = element_text(size=28,hjust = 0.5),
          legend.justification = c(1,1),
          legend.position = c(1,1),
          legend.box.margin = margin(c(10, 10, 10, 10)))
dev.off()

clinical.icustay.ids = sapply(clinical.data, function(x) x$icustay.id)

id = icustays$icustay_id[which(icustays$subject_id==3205)]
index = which(clinical.icustay.ids==id)



# qplot(as.duration(sepsis2.timestamps[[index]]-sepsis2.timestamps[[index]][1])/dhours(1),sepsis2.labels[[index]],geom="step",size=0.5)+
#     scale_y_continuous(breaks=c(0,1,2,3),labels=c("Nonsepsis","Sepsis","Severe Sepsis","Septic Shock"))+
#     xlab("Time (hours)")+ylab("")+xlim(0,115)+ggtitle("Clinical State Using Sepsis-2")+
#     theme(plot.title = element_text(hjust = 0.5, size=28),
#           axis.title = element_text(size=24),
#           axis.text = element_text(size=20),
#           plot.margin = margin(c(5,25,5,5)))

sepsis2.label.data = data.frame(t=as.duration(sepsis2.timestamps[[index]]-sepsis2.timestamps[[index]][1])/dhours(1),
                                label=sepsis2.labels[[index]])

png("figures/fig2a.png",width=800,height=600)
ggplot(sepsis2.label.data,aes(x=t,y=label))+geom_step(size=1)+
    scale_y_continuous(breaks=c(0,1,2,3),labels=c("Nonsepsis","Sepsis","Severe Sepsis","Septic Shock"))+
    xlab("Time (hours)")+ylab("")+xlim(0,115)+ggtitle("Clinical State Using Sepsis-2")+
    theme(plot.title = element_text(hjust = 0.5, size=28),
          axis.title = element_text(size=24),
          axis.text = element_text(size=20),
          plot.margin = margin(c(5,25,5,5)))
dev.off()

# qplot(as.duration(sofa.scores[[index]]$timestamps-sofa.scores[[index]]$timestamps[1])/dhours(1),sepsis3.labels[[index]],geom = "step")+
#     scale_y_continuous(breaks=c(0,1,2),labels=c("Nonsepsis","Sepsis","Septic Shock"))+
#     xlab("Time (hours)")+ylab("")+xlim(0,115)+ggtitle("Clinical State Using Sepsis-3")+
#     theme(plot.title = element_text(hjust = 0.5, size=28),
#           axis.title = element_text(size=24),
#           axis.text = element_text(size=20))

sepsis3.label.data = data.frame(t=as.duration(sofa.scores[[index]]$timestamps-sofa.scores[[index]]$timestamps[1])/dhours(1),
                                label=sepsis3.labels[[index]])

png("figures/fig2c.png",width=800,height=600)
ggplot(sepsis3.label.data,aes(x=t,y=label))+geom_step(size=1)+
    scale_y_continuous(breaks=c(0,1,2),labels=c("Nonsepsis","Sepsis","Septic Shock"))+
    xlab("Time (hours)")+ylab("")+xlim(0,115)+ggtitle("Clinical State Using Sepsis-3")+
    theme(plot.title = element_text(hjust = 0.5, size=28),
          axis.title = element_text(size=24),
          axis.text = element_text(size=20),
          plot.margin = margin(c(5,25,5,5)))
dev.off()

png("figures/fig2c.png",width=800,height=600)

dev.off()

#qplot(sepsis2.timestamps[[i]],sepsis2.labels[[i]],geom="step")+ylab("")+xlab("Time")
#qplot(sofa.scores[[i]]$timestamps,sepsis3.labels[[i]],geom="step")+ylab("")+xlab("Time")