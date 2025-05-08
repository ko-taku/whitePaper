// offchain-process.ts

import { ethers } from "ethers";
import axios from "axios";
import { Contract } from "ethers";
import auctionBettingAbi from "./abis/AuctionBetting.json"; // ABI JSON

const provider = new ethers.JsonRpcProvider("https://rpc-endpoint");
const signer = new ethers.Wallet("YOUR_ADMIN_PRIVATE_KEY", provider);
const contract = new Contract("AUCTION_BETTING_CONTRACT_ADDRESS", auctionBettingAbi, signer);

// 1. 경매 낙찰가 가져오기 (예: Auction 컨트랙트에서)
const getFinalAuctionPrice = async (): Promise<number> => {
    const price = await contract.getAuctionFinalPrice(); // 예시
    return Number(price);
};

// 2. 10% 근접 유저 선발
const selectTop10Percent = async (finalPrice: number) => {
    const allBets = await fetchAllBets(); // 백엔드에 저장된 배팅 정보
    const withDistance = allBets.map(b => ({
        ...b,
        distance: Math.abs(b.predictedPrice - finalPrice)
    }));

    withDistance.sort((a, b) => a.distance - b.distance);
    const top10Percent = withDistance.slice(0, Math.ceil(withDistance.length / 10));
    return top10Percent;
};

// 3. VRF 랜덤 요청 트리거 (1인당 최대 10회)
const triggerVRFRequests = async (users: any[]) => {
    for (const user of users) {
        await contract.requestRandomsForUser(user.address);
    }
};

// 4. 랜덤 수치 반영 완료 후 최고 점수 3명 선정
const rewardTop3 = async (top10: any[]) => {
    const sorted = top10.sort((a, b) => b.finalRandomScore - a.finalRandomScore).slice(0, 3);
    for (const user of sorted) {
        await contract.distributeAuctionToken(user.address, ethers.parseUnits("100", 18)); // 예: 100토큰
    }
};

// 백엔드 DB 또는 이벤트 통해 배팅자 전체 목록 가져오기
const fetchAllBets = async (): Promise<any[]> => {
    const res = await axios.get("https://your-server.com/bets");
    return res.data;
};

(async () => {
    const price = await getFinalAuctionPrice();
    const top10 = await selectTop10Percent(price);
    await triggerVRFRequests(top10);

    console.log("Waiting for VRF fulfillments...");
    // 잠시 대기 후 (몇 분) 다시 확인
    const top10WithScores = await fetchAllBets(); // finalRandomScore 필드 포함
    await rewardTop3(top10WithScores);
})();
