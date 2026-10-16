/* Calendar conventions are explicit; astronomical dates do not validate fortune predictions. */
window.SajuCalendar = {
    instant(year, month, day, hour = 12, minute = 0) {
        return new Date(Date.UTC(year, month - 1, day, hour, minute) - 9 * 3600000);
    },
    getJeolDateTime(year, name) {
        const data = window.SajuSolarTerms;
        const index = data.names.indexOf(name);
        const minute = data.years[year]?.[index];
        if (!Number.isFinite(minute)) throw Error('지원하지 않는 절기 연도입니다.');
        return new Date(minute * 60000);
    },
    format(date) {
        return new Date(date.getTime() + 9 * 3600000).toISOString().slice(0,16).replace('T',' ') + ' KST';
    },
    chart(input, calculate) {
        const {year, month, day, timeVal, longitude, exactTime = ''} = input;
        if (exactTime && !/^([01]\d|2[0-3]):[0-5]\d$/.test(exactTime)) throw Error('출생 시각을 확인해주세요.');
        const known = !!exactTime || timeVal !== 'unknown';
        const minutes = exactTime ? Number(exactTime.slice(0,2)) * 60 + Number(exactTime.slice(3)) : timeVal === 'unknown' ? 720 : Number(timeVal) * 120;
        const hour = Math.floor(minutes / 60), minute = minutes % 60;
        const birth = this.instant(year, month, day, hour, minute);
        // Longitude correction applies to the hour/day clock, never to the absolute solar-term instant.
        const corrected = new Date(Date.UTC(year, month - 1, day, hour, minute) - (135-longitude) * 4 * 60000);
        const hourBranch = known ? Math.floor(((corrected.getUTCHours() * 60 + corrected.getUTCMinutes() + 60) % 1440) / 120) : null;
        const yearPillar = calculate.getYearPillar(year, month, day, hour, minute);
        const monthPillar = calculate.getMonthPillar(year, month, day, hour, minute, yearPillar.stemIdx);
        const dayPillar = calculate.getDayPillar(corrected.getUTCFullYear(), corrected.getUTCMonth()+1, corrected.getUTCDate());
        const hourPillar = hourBranch === null ? {stemIdx:null,branchIdx:null} : {stemIdx:(dayPillar.stemIdx % 5 * 2 + hourBranch) % 10,branchIdx:hourBranch};
        const terms = [year-1,year,year+1].flatMap(y => window.SajuSolarTerms.years[y] ? window.SajuSolarTerms.names.filter((_,i)=>i%2===0).map(name=>({name,time:this.getJeolDateTime(y,name)})) : []).sort((a,b)=>a.time-b.time);
        const previous = terms.filter(t=>t.time<=birth).at(-1), next = terms.find(t=>t.time>birth);
        const official = window.SajuSolarTerms.officialYears.includes(year);
        const uncertaintyMinutes = exactTime ? 0 : known ? 60 : 720;
        const warnings = [];
        if (!known) warnings.push('출생 시각 미상: 시주를 산출하지 않습니다. 절입일에는 연주·월주가 달라질 수 있습니다.');
        else if (!exactTime) warnings.push('2시간 구간의 중앙 시각으로 계산했습니다. 정확한 시·분을 입력하면 경계 판정을 보완할 수 있습니다.');
        const nearest = Math.min(...terms.map(t=>Math.abs(t.time-birth)/60000));
        if (nearest <= uncertaintyMinutes + (official ? 1 : 5)) warnings.push('절입 경계에 가깝습니다. 입력 시각·공식 역서 대조 전에는 연주·월주를 확정하지 마세요.');
        if (year < 1962 || (year >= 1987 && year <= 1988)) warnings.push('과거 한국 표준시·서머타임이 적용되었을 수 있습니다. 이 앱은 UTC+09:00 고정 기준이므로 당시 출생 기록과 별도 대조가 필요합니다.');
        return {yearPillar,monthPillar,dayPillar,hourPillar,basis:{
            source:official ? '한국천문연구원 특일 정보 API · 검증된 절입 시각' : 'Astronomy Engine 2.1.19 천문 계산 · KASI 원자료 미제공 또는 검증 불일치 연도',
            retrievedAt:window.SajuSolarTerms.retrievedAt,
            timePolicy:'양력 · UTC+09:00 고정 · 연주 입춘 / 월주 12절입 · 경도 보정 지방평균시 · 보정 후 자정 일주 변경 · 균시차 미적용',
            precision:exactTime ? '출생 시·분 입력' : known ? '2시간 구간 중앙값' : '시각 미상: 정오 기준 연·월주 잠정 계산',
            longitudeCorrectionMinutes:Number(((longitude-135)*4).toFixed(2)),
            previousTerm:previous ? previous.name+' '+this.format(previous.time) : null,
            nextTerm:next ? next.name+' '+this.format(next.time) : null,
            warnings
        }};
    }
};
